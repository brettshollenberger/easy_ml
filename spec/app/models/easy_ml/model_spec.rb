require "spec_helper"

RSpec.describe EasyML::Models do
  let(:root_dir) do
    SPEC_ROOT.join("internal/app/data")
  end

  let(:datasource) do
    EasyML::Datasource.create(
      name: "dataset",
      datasource_type: :file,
      root_dir: root_dir
    )
  end

  let(:target) { "rev" }
  let(:date_col) { "created_date" }
  let(:months_test) { 2 }
  let(:months_valid) { 2 }
  let(:today) { EST.parse("2024-06-01") }

  let(:dataset_config) do
    {
      name: "My Dataset",
      datasource: datasource,
      splitter_attributes: {
        splitter_type: "DateSplitter",
        today: today,
        date_col: date_col,
        months_test: months_test,
        months_valid: months_valid
      }
    }
  end

  let(:hidden_cols) do
    %w[business_name state drop_me created_date]
  end

  let(:drop_if_null_cols) do
    %w[loan_purpose]
  end

  let(:dataset) do
    EasyML::Dataset.create(**dataset_config).tap do |dataset|
      dataset.refresh
      dataset.columns.find_by(name: target).update(is_target: true)
      dataset.columns.where(name: drop_if_null_cols).update_all(drop_if_null: true)
      dataset.columns.where(name: hidden_cols).update_all(hidden: true)
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
      name: "My model",
      root_dir: root_dir,
      model_type: :xgboost,
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

  let(:model) do
    EasyML::Model.new(model_config)
  end

  before(:each) do
    dataset.cleanup
    dataset.refresh!
  end

  after(:each) do
    dataset.cleanup
  end

  def build_model(params)
    Timecop.freeze(incr_time)
    EasyML::Model.new(params.reverse_merge!(
                        root_dir: root_dir,
                        dataset: dataset,
                        metrics: %w[mean_absolute_error],
                        task: :regression,
                        model_type: :xgboost,
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

  def cleanup
    paths = [
      File.join(root_dir, "xgboost_model.json"),
      File.join(root_dir, "xg_boost.bin")
    ]
    paths.each do |path|
      FileUtils.rm(path) if File.exist?(path)
    end
  end

  def mock_file_upload
    allow_any_instance_of(Aws::S3::Client).to receive(:put_object) do |_s3_client, args|
      expect(args[:bucket]).to eq "my-bucket"
    end.and_return(true)
  end

  describe "#load" do
    it "loads the model from a file", :focus do
      mock_file_upload

      model.name = "My Model" # Model name + version must be unique
      model.metrics = ["mean_absolute_error"]
      model.fit
      model.save
      expect(model.model_type).to eq "XGBoost"
      expect(File).to exist(model.model_file.full_path)

      loaded_model = EasyML::Model.find(model.id)
      expect(loaded_model.model_file.full_path).to eq(model.model_file.full_path)

      expect(loaded_model.predict(dataset.test(split_ys: true).first)).to eq(model.predict(dataset.test(split_ys: true).first))
      expect(model.version).to eq loaded_model.version
      expect(loaded_model.feature_names).to eq model.feature_names
      expect(loaded_model.feature_names).to_not include(dataset.target)
      model.cleanup!
    end
  end

  describe "#promote" do
    it "marks all other models of the same name as inference: false, and sets inference: true to itself" do
      mock_file_upload

      @time = EST.now
      Timecop.freeze(@time)

      # When model1 gets promoted, we want to have a copy of its file!
      # We're mocking the download from s3...
      #
      @mock_s3_location = SPEC_ROOT.join("saved_file.json")
      FileUtils.rm(@mock_s3_location) if File.exist?(@mock_s3_location)
      model1 = build_model(name: "Test Model", status: :training)
      FileUtils.cp(model1.model_file.full_path, @mock_s3_location)

      model2 = build_model(name: "Test Model", status: :training)
      model3 = build_model(name: "Test Model", status: :training)
      model4 = build_model(name: "Test Model", status: :training)
      model5 = build_model(name: "Test Model", status: :training)
      model6 = build_model(name: "Test Model", status: :training)
      other_model = build_model(name: "Other Model", status: :training)

      expect(File).to_not exist(model1.model_file.full_path)

      model6.promote
      other_model.promote

      expect(model1.reload).to_not be_inference
      expect(model2.reload).to_not be_inference
      expect(model3.reload).to_not be_inference
      expect(model4.reload).to_not be_inference
      expect(model5.reload).to_not be_inference
      expect(model6.reload).to be_inference
      expect(other_model.reload).to be_inference
      preds = other_model.predict(
        model1.dataset.test(split_ys: true).first
      )
      expect(preds.to_a).to all(be > 0)

      preds = model6.predict(
        model6.dataset.test(split_ys: true).first
      )
      expect(preds.to_a).to all(be > 0)

      model1.promote
      expect(model1).to be_inference
      expect(model6.reload).to_not be_inference

      # Newly promoted model can predict (downloads its file again when calling predict)
      expect(model1.model_file).to receive(:download).once do |_model|
        # Mock downloading from s3
        FileUtils.cp(@mock_s3_location, model1.model_file.full_path)
      end
      preds = model1.predict(model1.dataset.test(split_ys: true).first)
      expect(preds.to_a).to all(be > 0)
      expect(File).to exist(model1.model_file.full_path)

      FileUtils.rm(@mock_s3_location)
      model1.cleanup!
      other_model.cleanup!
    end

    def make_orchestrator
      dataset = EasyML::Data::Dataset.new(
        {
          verbose: false,
          drop_if_null: ["loan_purpose"],
          drop_cols: %w[business_name state id date],
          datasource: df,
          target: target,
          preprocessing_steps: {},
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

      EasyML::Orchestrator.new(
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

    xit "saves and reuses statistics for inference" do
      @time = EST.now
      Timecop.freeze(@time)

      orchestrator = make_orchestrator
      orchestrator.train # Model is now saved
      orchestrator.model.mark_live

      # Simulate another request, after the model has been marked live
      orchestrator2 = make_orchestrator

      df1 = orchestrator.features(new_df)
      df2 = orchestrator2.features(new_df)
      df1.columns.each do |col|
        expect(df1[col][0]).to eq(df2[col][0])
      end
      expect(df1["annual_revenue"]).to eq 3_000 # Median revenue
      expect(df1["loan_purpose_payroll"]).to eq 1

      expect(orchestrator.predict(new_df).first).to be_within(0.001).of(orchestrator2.predict(new_df).first)
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
