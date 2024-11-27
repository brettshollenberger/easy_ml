require "spec_helper"
require "support/model_spec_helper"

RSpec.describe EasyML::Models do
  include ModelSpecHelper
  let(:root_dir) do
    SPEC_ROOT.join("internal/app/data/titanic/core")
  end

  let(:datasource) do
    EasyML::Datasource.create(
      name: "Titanic Dataset",
      datasource_type: "file",
      root_dir: root_dir
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
        objective: objective
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

  describe "#promote" do
    it "snapshots the current model for predictions", :focus do
      mock_file_upload

      @time = EST.now
      Timecop.freeze(@time)

      # When model1 gets promoted, we want to have a copy of its file!
      # We're mocking the download from s3...
      #
      @mock_s3_location = SPEC_ROOT.join("saved_file.json")
      FileUtils.rm(@mock_s3_location) if File.exist?(@mock_s3_location)
      model1 = build_model(name: "Model 1")
      FileUtils.cp(model1.model_file.full_path, @mock_s3_location)

      model1.fit
      model1.save
      model1.promote
      existing_model = model1.latest_snapshot

      Timecop.freeze(@time + 2.hours)
      x_test, y_true = model1.dataset.locked.test(split_ys: true)
      y_true = y_true["Survived"]
      preds_after_one_iteration = Polars::Series.new(model1.predict(x_test))

      live_predictions = model1.latest_snapshot.predict(x_test)
      expect(live_predictions.sum).to be_within(0.01).of(preds_after_one_iteration.sum)

      model1.update(name: "RENAMED")
      model1.reload
      model1.hyperparameters.learning_rate = 0.01
      model1.hyperparameters.n_estimators = 10
      model1.hyperparameters.max_depth = 5
      model1.hyperparameters.regularization = 1.0
      model1.hyperparameters.early_stopping_rounds = 30
      model1.hyperparameters.min_child_weight = 5
      model1.hyperparameters.subsample = 0.8
      model1.hyperparameters.colsample_bytree = 0.8
      model1.hyperparameters.colsample_bylevel = 0.8
      pos_cases = y_true[y_true == 1].count
      neg_cases = y_true[y_true == 0].count
      model1.hyperparameters.scale_pos_weight = neg_cases / pos_cases.to_f

      model1.dataset.columns.where(name: "Age").update_all(hidden: true)
      model1.dataset.refresh
      model1.fit
      model1.save
      expect(model1.model_file.filename).to_not eq(existing_model.model_file.filename)
      preds_after_more_iterations = Polars::Series.new(model1.predict(x_test))

      expect(preds_after_more_iterations.sum).to_not eq(preds_after_one_iteration.sum)

      # The old model is still live! That's what we're using!
      expect(model1.dataset.train.columns).to_not include("Age")
      expect(model1.latest_snapshot.model_file.filename).to eq(existing_model.model_file.filename)
      live_predictions = model1.latest_snapshot.predict(x_test)
      expect(live_predictions.sum).to be_within(0.01).of(preds_after_one_iteration.sum)

      model1.snapshot
      live_predictions = model1.reload.latest_snapshot.predict(x_test)
      expect(live_predictions.sum).to be_within(0.01).of(preds_after_more_iterations.sum)
    end
  end

  describe "#cleanup" do
    it "keeps the live model, deletes the oldest version when training, and retains up to 5 versions per model name" do
      @time = EST.now
      Timecop.freeze(@time)
      # Create test models
      mock_file_upload
      live_model_x = build_model(name: "Model X", status: :training, created_at: 1.year.ago, dataset: dataset,
                                 metrics: %w[mean_absolute_error])
      live_model_x.promote

      recent_models = 7.times.map do |i|
        build_model(name: "Model X", created_at: (6 - i).days.ago)
      end

      old_versions_x = recent_models[0..2]
      recent_versions_x = recent_models[3..-1]

      expect(File).to exist(live_model_x.model_file.full_path)
      old_versions_x.each do |old_version|
        expect(File).to_not exist(old_version.model_file.full_path)
      end
      recent_versions_x.each.with_index do |recent_version, _idx|
        expect(File).to exist(recent_version.model_file.full_path)
      end

      # Create models with a different name
      live_model_y = build_model(name: "Model Y", status: :training, created_at: 1.year.ago)
      live_model_y.promote

      recent_y = 7.times.map do |i|
        build_model(name: "Model Y", created_at: (6 - i).days.ago)
      end

      old_versions_y = recent_y[0..2]
      recent_versions_y = recent_y[3..-1]

      # Simulate training a new model X
      build_model(name: "Model X")

      # add least recent x to old versions x
      old_versions_x << recent_versions_x.shift
      expect(old_versions_x.count).to eq 4
      old_versions_x.each do |old_version|
        expect(File).to_not exist(old_version.model_file.full_path)
      end
      recent_versions_x.each do |recent_version|
        expect(File).to exist(recent_version.model_file.full_path)
      end

      old_versions_y.each do |old_version|
        expect(File).to_not exist(old_version.model_file.full_path)
      end
      recent_versions_y.each do |recent_version|
        expect(File).to exist(recent_version.model_file.full_path)
      end

      live_model_x.cleanup!
      live_model_y.cleanup!
    end
  end
end
