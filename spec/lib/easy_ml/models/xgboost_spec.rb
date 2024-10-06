require "rails_helper"

RSpec.describe ML::Models::XGBoost do
  let(:root_dir) { Rails.root.join("spec/lib/ml/data") }
  let(:preprocessing_steps) do
    {
      training: {
        annual_revenue: {
          median: true,
          clip: { min: 0, max: 1_000_000 }
        },
        loan_purpose: {
          one_hot: true
        }
      }
    }
  end
  let(:target) { "rev" }
  let(:date_col) { "date" }
  let(:months_test) { 2 }
  let(:months_valid) { 2 }
  let(:today) { EST.parse("2024-06-01") }

  let(:dataset_config) do
    {
      root_dir: root_dir,
      verbose: false,
      drop_if_null: ["loan_purpose"],
      drop_cols: %w[business_name state],
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
  end

  let(:dataset) { EasyML::Dataset.new(**dataset_config) }

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

  let(:xgb) { described_class.new(**config) }

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

                          })
  end

  before do
    allow_any_instance_of(SyncedDirectory).to receive(:synced?).and_return(false)
    allow_any_instance_of(SyncedDirectory).to receive(:sync).and_return(true)
    allow_any_instance_of(SyncedDirectory).to receive(:clean_dir!).and_return(true)
    allow_any_instance_of(ML::Data::Datasource::S3Datasource).to receive(:refresh!).and_return(true)
    allow_any_instance_of(ML::Data::Dataset).to receive(:should_split?).and_return(true)

    mock_train(dataset, mock_train_data)
    mock_test(dataset, mock_test_data)
    mock_valid(dataset, mock_valid_data)
  end

  describe "#initialize" do
    it "sets up the model with correct attributes", :focus do
      expect(xgb.name).to eq("xgboost")
      expect(xgb.verbose).to be false
      expect(xgb.root_dir).to eq(File.join(root_dir, "models"))
      expect(xgb.hyperparameters).to be_a(ML::Models::Hyperparameters::XGBoost)
      expect(xgb.hyperparameters.learning_rate).to eq(0.05)
      expect(xgb.hyperparameters.max_depth).to eq(8)
    end
  end

  describe "#fit" do
    it "calls XGBoost.train with correct parameters", :focus do
      expect(XGBoost).to receive(:train) do |params, x, y|
        expect(params).to eq(xgb.hyperparameters.to_h)
        expect(x).to be_a(Polars::DataFrame)
        expect(x.columns).to match_array(%w[id business_name annual_revenue loan_purpose date])
        expect(y).to be_a(Polars::Series)
        expect(y.name).to eq("rev")
        expect(x.height).to eq(3) # Checking that it's using the train data
      end

      dataset.refresh!
      x_train, y_train = dataset.train(split_ys: true)
      dataset.fit(x_train)
      x_train = dataset.normalize(x_train, environment: "development")
      xgb.fit(x_train, y_train)
    end
  end

  describe "#predict" do
    let(:mock_model) { instance_double("XGBoostModel") }

    before do
      xgb.instance_variable_set(:@model, mock_model)
    end

    it "calls predict on the underlying XGBoost model with test data" do
      expect(mock_model).to receive(:predict) do |df|
        expect(df).to be_a(Polars::DataFrame)
        expect(df.height).to eq(2) # Checking that it's using the test data
        expect(df["id"].to_a).to eq([4, 5])
      end
      xgb.predict
    end
  end

  describe "#save" do
    let(:mock_xgboost) { class_double("XGBoost") }
    let(:mock_model) { instance_double("XGBoostModel") }

    before do
      stub_const("XGBoost", mock_xgboost)
      xgb.instance_variable_set(:@model, mock_model)
    end

    it "calls XGBoost.save_model with correct parameters" do
      expect(mock_xgboost).to receive(:save_model).with(mock_model, xgb.send(:model_path))
      xgb.save
    end
  end

  describe "#load" do
    let(:mock_xgboost) { class_double("XGBoost") }

    before do
      stub_const("XGBoost", mock_xgboost)
    end

    it "calls XGBoost.load_model with correct parameters" do
      expect(mock_xgboost).to receive(:load_model).with(xgb.send(:model_path))
      xgb.load
    end
  end

  describe "hyperparameters" do
    it "allows setting and getting hyperparameters" do
      xgb.hyperparameters.learning_rate = 0.1
      expect(xgb.hyperparameters.learning_rate).to eq(0.1)
    end

    it "converts hyperparameters to a hash" do
      expect(xgb.hyperparameters.to_h).to include(
        learning_rate: 0.05,
        max_depth: 8,
        n_estimators: 150,
        booster: "gbtree",
        objective: "reg:squarederror"
      )
    end
  end
end
