require "spec_helper"

RSpec.describe EasyML::Models do
  let(:root_dir) do
    SPEC_ROOT.join("lib/easy_ml/data/dataset/data/files/raw")
  end

  let(:datasource) do
    EasyML::Datasource.create(
      name: "dataset",
      datasource_type: :file,
      root_dir: root_dir
    )
  end

  let(:preprocessing_steps) do
    {
      training: {
        annual_revenue: {
          median: true,
          clip: { min: 0, max: 1_000_000 }
        },
        loan_purpose: {
          categorical: {
            categorical_min: 2,
            one_hot: true
          }
        }
      }
    }
  end
  let(:target) { "rev" }
  let(:date_col) { "created_date" }
  let(:months_test) { 2 }
  let(:months_valid) { 2 }
  let(:today) { EST.parse("2024-06-01") }

  let(:dataset_config) do
    {
      verbose: false,
      name: "My Dataset",
      datasource: datasource,
      drop_if_null: ["loan_purpose"],
      drop_cols: %w[business_name state drop_me created_date],
      target: target,
      preprocessing_steps: preprocessing_steps,
      splitter: {
        date: {
          today: today,
          date_col: date_col,
          months_test: months_test,
          months_valid: months_valid
        }
      }
    }
  end

  let(:dataset) { EasyML::Dataset.create(**dataset_config) }

  let(:hyperparameters) do
    {
      learning_rate: 0.05,
      max_depth: 8,
      n_estimators: 150,
      booster: "gbtree",
      objective: "reg:squarederror"
    }
  end

  let(:config) do
    {
      root_dir: root_dir,
      verbose: false,
      hyperparameters: hyperparameters
    }
  end

  let(:learning_rate) { 0.05 }
  let(:max_depth) { 8 }
  let(:task) { :regression }
  let(:objective) { "reg:squarederror" }
  let(:model_config) do
    {
      root_dir: root_dir,
      model_type: :xgboost,
      task: task,
      dataset: dataset,
      hyperparameters: {
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

  let(:model) do
    EasyML::Model.new(model_config)
  end

  before(:each) do
    dataset.cleanup
    dataset.refresh!
    model.cleanup!
  end

  after(:each) do
    dataset.cleanup
    model.cleanup!
  end

  def build_model(params)
    Timecop.freeze(incr_time)
    EasyML::Model.new(params.reverse_merge!(
                        dataset: dataset,
                        metrics: %w[mean_absolute_error],
                        task: :regression,
                        model_type: :xgboost,
                        hyperparameters: {
                          objective: "reg:squarederror"
                        }
                      )).tap do |model|
      model.fit
      model.save
    end
  end

  def incr_time
    @time += 1.second
  end

  def cleanup
    paths = [
      File.join(root_dir, "xgboost_model.json"),
      File.join(root_dir, "xg_boost.bin")
    ]
    paths.each do |path|
      FileUtils.rm(path) if File.exist?(path)
    end
  end

  describe "#load" do
    it "loads the model from a file" do
      model.name = "My Model" # Model name + version must be unique
      model.metrics = ["mean_absolute_error"]
      model.fit
      model.save
      expect(model.model_type).to eq "xgboost"

      loaded_model = EasyML::Model.find(model.id)

      expect(loaded_model.predict(dataset.test(split_ys: true).first)).to eq(model.predict(dataset.test(split_ys: true).first))
      expect(model.version).to eq loaded_model.version
      expect(loaded_model.feature_names).to eq model.feature_names
      expect(loaded_model.feature_names).to_not include(dataset.target)
    end
  end

  describe "#mark_live" do
    it "marks all other models of the same name as is_live: false, and sets is_live: true to itself" do
      @time = EST.now
      Timecop.freeze(@time)

      model1 = build_model(name: "Test Model", is_live: true)
      model2 = build_model(name: "Test Model", is_live: false)
      model3 = build_model(name: "Test Model", is_live: false)
      model4 = build_model(name: "Test Model", is_live: false)
      model5 = build_model(name: "Test Model", is_live: false)
      model6 = build_model(name: "Test Model", is_live: false)
      other_model = build_model(name: "Other Model", is_live: true)

      model3.mark_live

      # Old model can still download its model file and make predictions, even though it is NO longer on the machine
      # when we call this method.
      expect_any_instance_of(EasyML::Core::Uploaders::ModelUploader).to receive(:cache_stored_file!)
      expect_any_instance_of(EasyML::Core::Uploaders::ModelUploader).to receive(:full_cache_path!)

      expect(model1.reload.is_live).to be false
      expect(model2.reload.is_live).to be false
      expect(model3.reload.is_live).to be false
      expect(model4.reload.is_live).to be false
      expect(model5.reload.is_live).to be false
      expect(model6.reload.is_live).to be true
      expect(other_model.reload.is_live).to be true
      preds = other_model.predict(
        model1.dataset.test(split_ys: true).first
      )
      expect(preds.to_a).to all(be > 0)

      preds = model1.predict(
        model1.dataset.test(split_ys: true).first
      )
      expect(preds.to_a).to all(be > 0)
    end

    def make_trainer
      dataset = EasyML::Data::Dataset.new(
        {
          verbose: false,
          drop_if_null: ["loan_purpose"],
          drop_cols: %w[business_name state id date],
          datasource: df,
          target: target,
          preprocessing_steps: preprocessing_steps,
          splitter: {
            date: {
              today: today,
              date_col: date_col,
              months_test: months_test,
              months_valid: months_valid
            }
          }
        }
      )
      model = EasyML::Model.new({
                                  name: "My model",
                                  model: :xgboost,
                                  root_dir: root_dir,
                                  task: task,
                                  dataset: dataset,
                                  hyperparameters: {
                                    learning_rate: learning_rate,
                                    max_depth: max_depth,
                                    objective: objective
                                  }
                                })

      EasyML::Trainer.new(
        model: model,
        dataset: model.dataset,
        tuner: EasyML::Core::Tuner.new(
          n_trials: 1,
          model: model,
          objective: :mean_absolute_error,
          config: {
            learning_rate: { min: 0.01, max: 0.1 },
            n_estimators: { min: 1, max: 100 },
            max_depth: { min: 1, max: 8 }
          }
        )
      )
    end

    def new_df
      Polars::DataFrame.new({
                              business_name: ["Business X"],
                              annual_revenue: [nil],
                              loan_purpose: ["payroll"],
                              state: ["VIRGINIA"],
                              rev: [0],
                              date: "2024-01-01"
                            })
    end

    it "saves and reuses statistics for inference" do
      @time = EST.now
      Timecop.freeze(@time)

      trainer = make_trainer
      trainer.train # Model is now saved
      trainer.model.mark_live

      # Simulate another request, after the model has been marked live
      trainer2 = make_trainer

      df1 = trainer.features(new_df)
      df2 = trainer2.features(new_df)
      df1.columns.each do |col|
        expect(df1[col][0]).to eq(df2[col][0])
      end
      expect(df1["annual_revenue"]).to eq 3_000 # Median revenue
      expect(df1["loan_purpose_payroll"]).to eq 1

      expect(trainer.predict(new_df).first).to be_within(0.001).of(trainer2.predict(new_df).first)
    end
  end

  describe "#cleanup" do
    it "keeps the live model, deletes the oldest version when training, and retains up to 5 versions per model name" do
      @time = EST.now
      Timecop.freeze(@time)
      # Create test models
      live_model_x = build_model(name: "Model X", is_live: true, created_at: 1.year.ago, dataset: dataset,
                                 metrics: %w[mean_absolute_error])

      recent_models = 7.times.map do |i|
        build_model(name: "Model X", created_at: (6 - i).days.ago)
      end

      old_versions_x = recent_models[0..2]
      recent_versions_x = recent_models[3..-1]

      expect(File).to exist(live_model_x.file.path)
      old_versions_x.each do |old_version|
        expect(File).to_not exist(old_version.file.path)
      end
      recent_versions_x.each.with_index do |recent_version, idx|
        puts "version #{idx + 1} still exist?"
        expect(File).to exist(recent_version.file.path)
      end

      # Create models with a different name
      build_model(name: "Model Y", is_live: true, created_at: 1.year.ago)
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
        expect(File).to_not exist(old_version.file.path)
      end
      recent_versions_x.each do |recent_version|
        expect(File).to exist(recent_version.file.path)
      end

      old_versions_y.each do |old_version|
        expect(File).to_not exist(old_version.file.path)
      end
      recent_versions_y.each do |recent_version|
        expect(File).to exist(recent_version.file.path)
      end

      live_model_x.cleanup!
    end
  end
end
