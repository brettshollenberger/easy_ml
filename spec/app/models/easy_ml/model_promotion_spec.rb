require "spec_helper"
require "support/model_spec_helper"

RSpec.describe EasyML::Models do
  include ModelSpecHelper
  let(:day_1_dir) do
    SPEC_ROOT.join("internal/data/titanic/core")
  end

  let(:day_2_dir) do
    SPEC_ROOT.join("internal/data/titanic/extended")
  end

  let(:datasource) do
    EasyML::Datasource.create(
      name: "Titanic Dataset",
      datasource_type: "s3",
      s3_bucket: "titanic"
    )
  end

  let(:target) { "Survived" }
  let(:dataset_config) do
    {
      name: "My Dataset",
      datasource: datasource,
      splitter_attributes: {
        splitter_type: "EasyML::RandomSplitter"
      }
    }
  end

  let(:hidden_cols) do
    %w[Name Ticket Cabin]
  end

  let(:dataset) do
    EasyML::Dataset.create(**dataset_config).tap do |dataset|
      mock_s3_download(day_1_dir)

      dataset.cleanup
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
        splitter_type: "EasyML::DateSplitter",
        today: today,
        date_col: "date",
        months_test: months_test,
        months_valid: months_valid
      }
    )
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
    EasyML::Cleaner.clean!
  end

  after(:each) do
    EasyML::Cleaner.clean!
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

  def randomize_hypers(model)
    _, y_true = model.dataset.locked.test(split_ys: true)
    y_true = y_true["Survived"]

    model.hyperparameters.learning_rate = rand(0.01..0.1)
    model.hyperparameters.max_depth = rand(3..10)
    model.hyperparameters.regularization = rand(0.1..2.0)
    model.hyperparameters.early_stopping_rounds = rand(10..50)
    model.hyperparameters.min_child_weight = rand(1..10)
    model.hyperparameters.subsample = rand(0.5..1.0)
    model.hyperparameters.colsample_bytree = rand(0.5..1.0)
    model.hyperparameters.colsample_bylevel = rand(0.5..1.0)
    model.hyperparameters.n_estimators = 10
    pos_cases = y_true[y_true == 1].count
    neg_cases = y_true[y_true == 0].count
    model.hyperparameters.scale_pos_weight = neg_cases / pos_cases.to_f
  end

  describe "#promote" do
    it "uses snapshot model for prediction" do
      mock_s3_upload

      @time = EST.now
      Timecop.freeze(@time)

      model.fit
      model.save
      model.promote
      model_v1 = model.latest_snapshot

      Timecop.freeze(@time + 2.hours)
      x_test, y_true = model.dataset.locked.test(split_ys: true)
      y_true["Survived"]
      preds_v1 = Polars::Series.new(model.predict(x_test))

      live_predictions = model.latest_snapshot.predict(x_test)
      expect(live_predictions.sum).to be_within(0.01).of(preds_v1.sum)

      # Change dataset configuration
      model.dataset.columns.where(name: "Age").update_all(hidden: true)
      model.dataset.refresh

      # Re-train
      randomize_hypers(model)
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

    it "uses locked dataset when running predictions" do
      mock_s3_upload

      @time = EST.now
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

      x_test, y_true = model.dataset.locked.test(split_ys: true)
      y_true["Survived"]
      preds_v1 = Polars::Series.new(model.predict(x_test))

      live_predictions = model.latest_snapshot.predict(x_test)
      expect(live_predictions.sum).to be_within(0.01).of(preds_v1.sum)

      # Re-train
      mock_s3_download(day_2_dir) # Download a DIFFERENT version of the dataset

      # Change dataset configuration
      model.dataset.columns.where(name: "Age").update_all(hidden: true)
      model.dataset.refresh

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

      model.snapshot # Now the latest snapshot becomes v2
      live_predictions = model.reload.latest_snapshot.predict(x_test)
      expect(live_predictions.sum).to be_within(0.01).of(retrain_preds.sum)
    end

    # Expect snapshot to download snapshot file from s3 if not local
    # Create clean spec
  end
end
