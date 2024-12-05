require "spec_helper"
require "support/model_spec_helper"

RSpec.describe EasyML::Models do
  include ModelSpecHelper

  let(:day_1_dir) do
    titanic_core_dir
  end

  let(:day_2_dir) do
    titanic_extended_dir
  end

  let(:datasource) do
    EasyML::Datasource.create(
      name: "Titanic Core",
      datasource_type: "s3",
      s3_bucket: "titanic"
    )
  end

  let(:target) { "Survived" }
  let(:dataset_config) do
    {
      name: "Titanic Dataset",
      datasource: datasource,
      splitter_attributes: {
        splitter_type: "random"
      }
    }
  end

  let(:hidden_cols) do
    %w[Name Ticket Cabin]
  end

  let(:dataset) do
    mock_s3_download(day_1_dir)
    mock_s3_upload

    EasyML::Dataset.create(**dataset_config).tap do |dataset|
      dataset.refresh
      dataset.columns.find_by(name: target).update(is_target: true)
      dataset.columns.where(name: hidden_cols).update_all(hidden: true)
      dataset.columns.find_by(name: "Sex").update(preprocessing_steps: {
                                                    training: {
                                                      method: :categorical,
                                                      params: {
                                                        one_hot: true
                                                      }
                                                    }
                                                  })
      dataset.columns.find_by(name: "Embarked").update(preprocessing_steps: {
                                                         training: {
                                                           method: :categorical,
                                                           params: {
                                                             one_hot: true
                                                           }
                                                         }
                                                       })
      dataset.columns.find_by(name: "Age").update(preprocessing_steps: {
                                                    training: {
                                                      method: :median
                                                    }
                                                  })
      dataset.refresh
    end
  end

  let(:hyperparameters) do
    {
      learning_rate: 0.05,
      max_depth: 8,
      n_estimators: 1,
      booster: "gbtree",
      objective: "reg:squarederror"
    }
  end

  let(:learning_rate) { 0.05 }
  let(:max_depth) { 8 }
  let(:task) { :regression }
  let(:objective) { "reg:squarederror" }
  let(:model_config) do
    {
      name: "My model",
      model_type: "xgboost",
      task: task,
      dataset: dataset,
      hyperparameters: {
        booster: :gbtree,
        learning_rate: learning_rate,
        max_depth: max_depth,
        objective: objective,
        n_estimators: 1
      }
    }
  end

  let(:df) do
    Polars::DataFrame.new({
                            "id" => [1, 2, 3, 4, 5, 6, 7, 8, 9, 10],
                            "business_name" => ["Business A", "Business B", "Business C", "Business D", "Business E", "Business F",
                                                "Business G", "Business H", "Business I", "Business J"],
                            "annual_revenue" => [1000, 2000, 3000, 4000, 5000, 6000, 7000, 8000, 9000, 10_000],
                            "loan_purpose" => %w[payroll payroll payroll expansion payroll inventory equipment
                                                 marketing equipment marketing],
                            "state" => %w[VIRGINIA INDIANA WYOMING PA WA MN UT CA DE FL],
                            "rev" => [100, 0, 0, 200, 0, 500, 7000, 0, 0, 10],
                            "date" => %w[2021-01-01 2021-05-01 2022-01-01 2023-01-01 2024-01-01
                                         2024-02-01 2024-02-01 2024-03-01 2024-05-01 2024-06-01]
                          }).with_column(
                            Polars.col("date").str.strptime(Polars::Datetime, "%Y-%m-%d")
                          )
  end

  let(:polars_datasource) do
    EasyML::Datasource.create!(
      name: "Polars datasource",
      datasource_type: "polars",
      df: df
    )
  end

  let(:dataset2) do
    config = dataset_config.merge(
      datasource: polars_datasource,
      splitter_attributes: {
        splitter_type: "date",
        today: today,
        date_col: "date",
        months_test: months_test,
        months_valid: months_valid
      }
    )
    mock_s3_download(day_1_dir)
    mock_s3_upload

    EasyML::Dataset.create(**config).tap do |dataset|
      dataset.refresh
      dataset.columns.find_by(name: "rev").update(is_target: true)
      dataset.columns.where(name: %w[business_name state date]).update_all(hidden: true)
      dataset.columns.find_by(name: "annual_revenue").update(preprocessing_steps: {
                                                               training: {
                                                                 method: :median,
                                                                 params: {
                                                                   clip: {
                                                                     min: 0, max: 1_000_000
                                                                   }
                                                                 }
                                                               }
                                                             })
      dataset.columns.find_by(name: "loan_purpose").update(preprocessing_steps: {
                                                             training: {
                                                               method: :categorical,
                                                               params: {
                                                                 categorical_min: 2,
                                                                 one_hot: true
                                                               }
                                                             }
                                                           })
    end
  end

  let(:model) do
    EasyML::Model.new(model_config)
  end

  before(:each) do
    EasyML::Cleaner.clean
  end

  after(:each) do
    EasyML::Cleaner.clean
  end

  def build_model(params)
    Timecop.freeze(incr_time)
    EasyML::Model.new(params.reverse_merge!(
                        dataset: dataset,
                        metrics: %w[mean_absolute_error],
                        task: :regression,
                        model_type: "xgboost",
                        hyperparameters: {
                          objective: "reg:squarederror",
                          n_estimators: 1
                        }
                      )).tap do |model|
      model.fit
      model.save
    end
  end

  def incr_time
    @time += 1.second
  end

  describe "#promote" do
    it "uses snapshot model for prediction" do
      mock_s3_upload

      @time = EasyML::Support::EST.now
      Timecop.freeze(@time)

      model.fit
      model.save
      model.promote
      model_v1 = model.latest_snapshot

      Timecop.freeze(@time + 2.hours)
      x_test, y_true = model.dataset.processed.test(split_ys: true)
      y_true["Survived"]
      preds_v1 = Polars::Series.new(model.predict(x_test))

      live_predictions = model.latest_snapshot.predict(x_test)
      expect(live_predictions.sum).to be_within(0.01).of(preds_v1.sum)

      # Change dataset configuration
      model.dataset.columns.where(name: "Age").update_all(hidden: true)
      model.dataset.refresh

      # Re-train
      y_true = y_true["Survived"]
      randomize_hypers(model) do
        pos_cases = y_true[y_true == 1].count
        neg_cases = y_true[y_true == 0].count
        [pos_cases, neg_cases]
      end
      model.fit
      model.save
      model_v2 = model
      model_v1.reload

      # retrained model_file is distinct from v1 model_file
      expect(model_v2.model_file.filename).to_not eq(model_v1.model_file.filename)

      retrain_preds = Polars::Series.new(model_v2.predict(x_test))
      expect(retrain_preds.sum).to_not eq(preds_v1.sum)

      # The v1 model dataset configuration is NOT the same as the current model dataset
      expect(model_v2.dataset.train.columns).to_not include("Age")
      expect(model_v1.dataset.train.columns).to include("Age")

      expect(model_v2.latest_snapshot.model_file.filename).to eq(model_v1.model_file.filename)
      live_predictions = model_v2.latest_snapshot.predict(x_test)
      expect(live_predictions.sum).to be_within(0.01).of(preds_v1.sum) # Even though we use "v2" model to load the snapshot, the latest LIVE snapshot is v1

      model.snapshot # Now the latest snapshot becomes v2
      live_predictions = model.reload.latest_snapshot.predict(x_test)
      expect(live_predictions.sum).to be_within(0.01).of(retrain_preds.sum)
    end

    it "uses historical dataset when running predictions" do
      mock_s3_upload

      @time = EasyML::Support::EST.now
      Timecop.freeze(@time)

      model.fit
      model.save

      # When model1 gets promoted, we want to have a copy of its file!
      # We're mocking the download from s3...
      #
      @mock_s3_location = SPEC_ROOT.join("saved_file.json")
      FileUtils.rm(@mock_s3_location) if File.exist?(@mock_s3_location)
      FileUtils.cp(model.model_file.full_path, @mock_s3_location)

      model.promote
      model_v1 = model.latest_snapshot

      Timecop.freeze(@time + 2.hours)

      x_test, y_true = model.dataset.processed.test(split_ys: true)
      y_true["Survived"]
      preds_v1 = Polars::Series.new(model.predict(x_test))

      live_predictions = model.latest_snapshot.predict(x_test)
      expect(live_predictions.sum).to be_within(0.01).of(preds_v1.sum)

      # By default, we read from the directory with the name provided,
      # so this will switch us to using a bigger dataset
      datasource.name = "Titanic Extended"
      datasource.save
      mock_s3_download(day_2_dir) # Download a DIFFERENT version of the dataset

      # Change dataset configuration
      model.dataset.columns.where(name: "Age").update_all(hidden: true)
      model.dataset.refresh! # Requires a full refresh! because we changed our source

      y_true = y_true["Survived"]
      randomize_hypers(model) do
        pos_cases = y_true[y_true == 1].count
        neg_cases = y_true[y_true == 0].count
        [pos_cases, neg_cases]
      end
      model.fit
      model.save
      model_v2 = model
      model_v1.reload

      expect(model_v1.dataset.data.count).to eq 500
      expect(model.dataset.data.count).to eq 891

      # Statistics are kept separate
      expect(model_v1.dataset.statistics.dig("raw", "Survived", "num_rows").first).to eq 500
      expect(model.dataset.statistics.dig("raw", "Survived", "num_rows").first).to eq 891

      # retrained model_file is distinct from v1 model_file
      expect(model_v2.model_file.filename).to_not eq(model_v1.model_file.filename)

      retrain_preds = Polars::Series.new(model_v2.predict(x_test))
      expect(retrain_preds.sum).to_not eq(preds_v1.sum)

      # The v1 model dataset configuration is NOT the same as the current model dataset
      expect(model_v2.dataset.train.columns).to_not include("Age")
      expect(model_v1.dataset.train.columns).to include("Age")

      expect(model_v2.latest_snapshot.model_file.filename).to eq(model_v1.model_file.filename)
      live_predictions = model_v2.latest_snapshot.predict(x_test)
      expect(live_predictions.sum).to be_within(0.01).of(preds_v1.sum) # Even though we use "v2" model to load the snapshot, the latest LIVE snapshot is v1

      model.promote # Now the latest snapshot becomes v2
      live_predictions = model.reload.latest_snapshot.predict(x_test)
      expect(live_predictions.sum).to be_within(0.01).of(retrain_preds.sum)
      expect(model.latest_snapshot.dataset.data.count).to eq 891
    end

    it "downloads the old splits from S3 if they aren't present locally" do
      FileUtils.rm_rf(SPEC_ROOT.join("backups"))

      mock_s3_upload

      @time = EasyML::Support::EST.parse("2024-01-01")
      Timecop.freeze(@time)

      model.fit
      model.save

      Timecop.freeze(EasyML::Support::EST.parse("2024-02-02"))

      model.promote
      model_v1 = model.latest_snapshot

      expect(model.dataset.raw.dir).to match(/20240202050000/)
      expect(model_v1.dataset.raw.dir).to match(/20240101050000/)

      expect(model.dataset.processed.dir).to match(/20240202050000/)
      expect(model_v1.dataset.processed.dir).to match(/20240101050000/)

      Timecop.freeze(@time + 2.hours)

      x_test, y_true = model.dataset.processed.test(split_ys: true)
      y_true["Survived"]
      preds_v1 = Polars::Series.new(model.predict(x_test))

      live_predictions = model.latest_snapshot.predict(x_test)
      expect(live_predictions.sum).to be_within(0.01).of(preds_v1.sum)

      # By default, we read from the directory with the name provided,
      # so this will switch us to using a bigger dataset
      datasource.name = "Titanic Extended"
      datasource.save
      mock_s3_download(day_2_dir) # Download a DIFFERENT version of the dataset

      # Change dataset configuration
      model.dataset.columns.where(name: "Age").update_all(hidden: true)
      model.dataset.refresh! # Requires a full refresh! because we changed our source

      randomize_hypers(model)
      model.fit
      model.save
      model_v2 = model
      model_v1.reload

      expect(model_v1.dataset.data.count).to eq 500
      expect(model.dataset.data.count).to eq 891

      # Statistics are kept separate
      expect(model_v1.dataset.statistics.dig("raw", "Survived", "num_rows").first).to eq 500
      expect(model.dataset.statistics.dig("raw", "Survived", "num_rows").first).to eq 891

      # retrained model_file is distinct from v1 model_file
      expect(model_v2.model_file.filename).to_not eq(model_v1.model_file.filename)

      retrain_preds = Polars::Series.new(model_v2.predict(x_test))
      expect(retrain_preds.sum).to_not eq(preds_v1.sum)

      # The v1 model dataset configuration is NOT the same as the current model dataset
      expect(model_v2.dataset.train.columns).to_not include("Age")
      expect(model_v1.dataset.train.columns).to include("Age")

      expect(model_v2.latest_snapshot.model_file.filename).to eq(model_v1.model_file.filename)
      live_predictions = model_v2.latest_snapshot.predict(x_test)
      expect(live_predictions.sum).to be_within(0.01).of(preds_v1.sum) # Even though we use "v2" model to load the snapshot, the latest LIVE snapshot is v1

      FileUtils.mkdir_p(SPEC_ROOT.join("backups/datasets"))
      FileUtils.mkdir_p(SPEC_ROOT.join("backups/models"))
      FileUtils.mv(model_v1.dataset.root_dir, SPEC_ROOT.join("backups/datasets")) # Move the dataset, so we can mock s3 download

      model.promote # Now the latest snapshot becomes v2

      # Since the v1 model is no longer live, we've deleted the model file... we need to expect it'll be requested from s3 too
      FileUtils.mv(model_v1.model_file.full_path, SPEC_ROOT.join("backups/models"))

      model_v2 = model.latest_snapshot
      preds_v2 = model_v2.predict(x_test)

      expect(model_v1.model_file).to receive(:download) do
        FileUtils.mv(
          Dir.glob(SPEC_ROOT.join("backups/models/*.json")).first,
          model_v1.model_file.full_path
        )
      end

      expect(model_v1.dataset.processed).to receive(:download) do
        FileUtils.mv(
          SPEC_ROOT.join("backups/datasets"),
          model_v1.dataset.root_dir
        )
      end

      # Both models can still predict
      expect(model_v1.predict(x_test).sum.round(2)).to eq preds_v1.sum.round(2)
      expect(model_v2.predict(x_test).sum.round(2)).to eq preds_v2.sum.round(2)

      FileUtils.rm_rf(SPEC_ROOT.join("backups"))
    end
  end
end
