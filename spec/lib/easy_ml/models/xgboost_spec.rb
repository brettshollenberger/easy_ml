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

    describe "#save" do
      it "saves the model to a file / remote storage" do
        model.name = "My Model"
        model.metrics = ["mean_absolute_error"]
        model.fit
        model.save

        file_path = model.file.file.file
        expect(File).to exist(file_path)
        expect(File.size(file_path)).to be > 0
      end
    end

    describe "#load" do
      it "loads the model from a file" do
        model.name = "My Model" # Model name + version must be unique
        model.metrics = ["mean_absolute_error"]
        model.fit
        model.save
        expect(model.ml_model).to eq "xg_boost"

        loaded_model = EasyML::Models::XGBoost.find(model.id)
        loaded_model.load

        expect(loaded_model.predict(dataset.test(split_ys: true).first)).to eq(model.predict(dataset.test(split_ys: true).first))
      end

      it "works on S3 storage", :fog do
        s3_url = "https://s3-bucket.amazonaws.com/model.json"
        allow_any_instance_of(CarrierWave::Storage::Fog::File).to receive(:url).and_return(s3_url)

        model.name = "S3 Model"
        model.metrics = ["mean_absolute_error"]
        model.fit
        model.save

        loaded_model = EasyML::Models::XGBoost.find(model.id)

        allow(loaded_model.file).to receive(:download) do |&block|
          File.open(model.file.path, "rb", &block)
        end

        loaded_model.load
        expect(loaded_model.predict(dataset.test(split_ys: true).first)).to eq(model.predict(dataset.test(split_ys: true).first))
      end
    end

    describe "#mark_live" do
      it "marks all other models of the same name as is_live: false, and sets is_live: true to itself" do
        model1 = model_class.create(name: "Test Model", is_live: true)
        model2 = model_class.create(name: "Test Model", is_live: false)
        model3 = model_class.create(name: "Test Model", is_live: false)
        other_model = model_class.create(name: "Other Model", is_live: true)

        model3.mark_live

        expect(model1.reload.is_live).to be false
        expect(model2.reload.is_live).to be false
        expect(model3.reload.is_live).to be true
        expect(other_model.reload.is_live).to be true
      end
    end

    describe "#cleanup" do
      it "keeps the live model, deletes the oldest version when training, and retains up to 5 versions per model name" do
        # Create test models
        live_model_x = model_class.create(name: "Model X", is_live: true, created_at: 1.year.ago)
        old_versions_x = 5.times.map { |i| model_class.create(name: "Model X", created_at: (6 - i).days.ago) }

        # Create models with a different name
        live_model_y = model_class.create(name: "Model Y", is_live: true, created_at: 1.year.ago)
        old_versions_y = 5.times.map { |i| model_class.create(name: "Model Y", created_at: (6 - i).days.ago) }

        # Create test files
        all_models = [live_model_x] + old_versions_x + [live_model_y] + old_versions_y
        all_models.each do |m|
          file_path = File.join(root_dir, "#{m.name.underscore}_#{m.id}.json")
          File.write(file_path, "test content")
          allow(m).to receive(:file).and_return(double(path: file_path))
        end

        # Simulate training a new model X
        new_model_x = model_class.new(name: "Model X")
        allow(new_model_x).to receive(:fit) do
          new_model_x.save
          new_model_x.cleanup
        end

        # Train the new model X (which should trigger cleanup)
        new_model_x.fit

        # Check results for Model X
        expect(File.exist?(live_model_x.file.path)).to be true # Live model X should always be kept
        expect(File.exist?(old_versions_x.first.file.path)).to be false # Oldest version of X should be deleted
        expect( # Other 4 old versions of X should be kept
          old_versions_x[1..].all? do |m|
            File.exist?(m.file.path)
          end
        ).to be true
        expect(File.exist?(new_model_x.file.path)).to be true # New model X should be kept

        # Check results for Model Y
        expect(File.exist?(live_model_y.file.path)).to be true # Live model Y should always be kept
        expect(old_versions_y.all? { |m| File.exist?(m.file.path) }).to be true # All versions of Y should be kept

        # Verify we have exactly 6 models for X: 1 live + 5 versions (including the new one)
        existing_models_x = [live_model_x] + old_versions_x + [new_model_x]
        expect(existing_models_x.count { |m| File.exist?(m.file.path) }).to eq(6)

        # Verify we have exactly 6 models for Y: 1 live + 5 versions
        existing_models_y = [live_model_y] + old_versions_y
        expect(existing_models_y.count { |m| File.exist?(m.file.path) }).to eq(6)
      end
    end
  end
end
