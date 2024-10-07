require "spec_helper"
require "xgboost"

RSpec.describe EasyML::Models do
  let(:root_dir) { File.expand_path("..", Pathname.new(__FILE__)) }
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
  let(:date_col) { "date" }
  let(:months_test) { 2 }
  let(:months_valid) { 2 }
  let(:today) { EST.parse("2024-06-01") }

  let(:dataset_config) do
    {
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

  let(:dataset) { EasyML::Data::Dataset.new(**dataset_config) }

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
  let(:model_config) do
    {
      root_dir: root_dir,
      dataset: dataset,
      hyperparameters: {
        learning_rate: learning_rate,
        max_depth: max_depth
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

  describe "XGBoost" do
    let(:model) do
      model_class.new(model_config)
    end
    let(:model_class) do
      EasyML::Models::XGBoost
    end
    let(:xgb) { ::XGBoost }

    def cleanup
      paths = [
        File.join(root_dir, "xgboost_model.json"),
        File.join(root_dir, "xg_boost.bin")
      ]
      paths.each do |path|
        FileUtils.rm(path) if File.exist?(path)
      end
    end

    before(:each) do
      dataset.refresh!
      cleanup
    end
    after(:each) do
      dataset.cleanup
    end

    describe "#fit" do
      it "trains the model" do
        expect(::XGBoost).to receive(:train) do |params, x, _evals|
          expect(params).to eq(model.hyperparameters.to_h)
          expect(x.data.count).to eq(5) # Checking that it's using the train data
        end.and_call_original

        model.fit
      end
    end

    describe "#predict" do
      it "makes predictions" do
        x_test, = dataset.test(split_ys: true)
        model.fit
        preds = model.predict(x_test)
        expect(preds).to all(be_a Numeric)
      end
    end

    describe "#feature_importances" do
      it "supports feature importances" do
        model.fit
        expect(model.feature_importances).to match(hash_including({ "annual_revenue" => a_value_between(0.0, 1.0),
                                                                    "loan_purpose_payroll" => a_value_between(0.0,
                                                                                                              1.0) }))
      end
    end

    describe "#model_path" do
      it "has one" do
        expect(model.model_path).to eq File.join(root_dir, "xg_boost.bin")
      end
    end

    describe "#save" do
      it "saves the model to a file" do
        model.fit
        file_path = File.join(root_dir, "xgboost_model.json")
        model.save(file_path)

        expect(File).to exist(file_path)
        expect(File.size(file_path)).to be > 0

        default_path = model.model_path
        model.save
        expect(File).to exist(default_path)
        expect(File.size(file_path)).to be > 0
      end
    end

    describe "#load" do
      it "loads the model from a file", :focus do
        model.fit
        file_path = File.join(root_dir, "xgboost_model.json")
        model.save(file_path)

        loaded_model = model_class.new(model_config)
        loaded_model.load(file_path)

        expect(loaded_model.predict(dataset.test(split_ys: true).first)).to eq(model.predict(dataset.test(split_ys: true).first))
      end
    end
  end
end
