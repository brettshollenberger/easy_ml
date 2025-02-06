require "spec_helper"
require "support/model_spec_helper"

RSpec.describe EasyML::Models do
  include ModelSpecHelper

  let(:datasource) do
    EasyML::Datasource.create(
      name: "Single file",
      datasource_type: "file",
    )
  end

  let(:target) { "rev" }
  let(:date_col) { "created_date" }
  let(:months_test) { 2 }
  let(:months_valid) { 2 }
  let(:today) { EasyML::Support::EST.parse("2024-06-01") }

  let(:dataset_config) do
    {
      name: "My Dataset",
      datasource: datasource,
      splitter_attributes: {
        splitter_type: "date",
        today: today,
        date_col: date_col,
        months_test: months_test,
        months_valid: months_valid,
      },
    }
  end

  let(:hidden_cols) do
    %w[business_name state drop_me created_date]
  end

  let(:drop_if_null_cols) do
    %w[loan_purpose]
  end

  let(:dataset) do
    mock_s3_download(single_file_dir)
    mock_s3_upload

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
                                                                     min: 0, max: 1_000_000,
                                                                   },
                                                                 },
                                                               },
                                                             })
      dataset.columns.find_by(name: "loan_purpose").update(preprocessing_steps: {
                                                             training: {
                                                               method: :categorical,
                                                               params: {
                                                                 categorical_min: 2,
                                                                 one_hot: true,
                                                               },
                                                             },
                                                           })
    end
  end

  let(:hyperparameters) do
    {
      learning_rate: 0.05,
      max_depth: 8,
      n_estimators: 1,
      booster: "gbtree",
      objective: "reg:squarederror",
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
        n_estimators: 1,
      },
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
                                         2024-02-01 2024-02-01 2024-03-01 2024-05-01 2024-06-01],
                          }).with_column(
      Polars.col("date").str.strptime(Polars::Datetime, "%Y-%m-%d")
    )
  end

  let(:polars_datasource) do
    EasyML::Datasource.create!(
      name: "Polars datasource",
      datasource_type: "polars",
      df: df,
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
        months_valid: months_valid,
      },
    )
    mock_s3_download(single_file_dir)
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
                                                                     min: 0, max: 1_000_000,
                                                                   },
                                                                 },
                                                               },
                                                             })
      dataset.columns.find_by(name: "loan_purpose").update(preprocessing_steps: {
                                                             training: {
                                                               method: :categorical,
                                                               params: {
                                                                 categorical_min: 2,
                                                                 one_hot: true,
                                                               },
                                                             },
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
        n_estimators: 1,
      },
    )).tap do |model|
      model.fit
      model.save
    end
  end

  def incr_time
    @time ||= EST.now
    @time += 1.second
  end

  describe "#load" do
    it "loads the model from a file" do
      mock_s3_upload

      model.name = "My Model" # Model name + version must be unique
      model.metrics = ["mean_absolute_error"]
      model.fit
      model.save
      expect(model.model_type).to eq "xgboost"
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

  describe "#api_fields" do
    let(:dataset) { titanic_dataset }
    let(:model) { build_model(dataset: dataset) }

    let(:feature) do
      dataset.features.create!(
        name: "FamilySize",
        feature_class: "FamilySizeFeature",
        needs_fit: true,
        feature_position: 1,
      )
    end

    before do
      # Create computed column via feature
      feature
      dataset.refresh!

      # Create preprocessed column
      dataset.columns.find_by(name: "Age").update(
        preprocessing_steps: { training: { method: "mean", params: { clip: { min: 0, max: 100 } } } },
      )
    end

    it "returns API documentation for non-computed columns" do
      api_fields = model.api_fields

      expect(api_fields).to include(
        url: EasyML::Engine.routes.url_helpers.predictions_path,
        method: "POST",
      )

      input_fields = api_fields.dig(:data, :input)
      # Should include raw, unprocessed columns
      expect(input_fields.dig("PassengerId", :datatype).to_sym).to eq :integer
      expect(input_fields.dig("PassengerId", :required)).to eq false

      # Should not include computed columns
      expect(input_fields.keys).not_to include("FamilySize")

      # Should include preprocessed columns but mark them as not required
      expect(input_fields["Age"]).to include(
        datatype: be_present,
        required: false,
      )
    end
  end
end
