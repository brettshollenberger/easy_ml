require "spec_helper"
require "xgboost"

RSpec.describe EasyML::Models do
  before(:each) do
    model_class.new.cleanup!
  end

  after(:each) do
    model_class.new.cleanup!
  end

  def build_model(params)
    Timecop.freeze(incr_time)
    model_class.new(params.reverse_merge!(dataset: dataset, metrics: %w[mean_absolute_error])).tap do |model|
      model.fit
      model.save
    end
  end

  def incr_time
    @time += 1.second
  end

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

      it "calls fit multiple times" do
        model.fit
        expect { model.fit }.to_not raise_error
      end
    end

    describe "#predict" do
      it "makes predictions" do
        x_test, = dataset.test(split_ys: true)
        model.fit
        preds = model.predict(x_test)
        expect(preds).to all(be_a Numeric)
      end

      it "evaluates regression predictions" do
        xs, ys = dataset.data(split_ys: true)
        model.metrics = %w[mean_absolute_error mean_squared_error root_mean_squared_error r2_score]
        model.fit
        preds = model.predict(xs)

        # Evaluate all regression metrics
        evaluation_metrics = model.evaluate(y_pred: preds, y_true: ys)

        expect(evaluation_metrics[:mean_absolute_error]).to be_between(784, 785)
        expect(evaluation_metrics[:mean_squared_error]).to be_between(4_793_806, 4_793_807)
        expect(evaluation_metrics[:root_mean_squared_error]).to be_between(2189, 2190)
        expect(evaluation_metrics[:r2_score]).to be_between(-Float::INFINITY, 1)
      end

      it "evaluates classification predictions" do
        df = Polars::DataFrame.new({
                                     "id" => [1, 2, 3, 4, 5, 6, 7, 8, 9, 10],
                                     "business_name" => ["Business A", "Business B", "Business C", "Business D", "Business E", "Business F",
                                                         "Business G", "Business H", "Business I", "Business J"],
                                     "annual_revenue" => [1000, 2000, 3000, 4000, 5000, 6000, 7000, 8000, 9000, 10_000],
                                     "loan_purpose" => %w[payroll payroll payroll expansion payroll inventory equipment
                                                          marketing equipment marketing],
                                     "state" => %w[VIRGINIA INDIANA WYOMING PA WA MN UT CA DE FL],
                                     "did_convert" => %w[converts not_converts converts converts converts
                                                         not_converts not_converts converts converts not_converts],
                                     "date" => %w[2021-01-01 2021-05-01 2022-01-01 2023-01-01 2024-01-01
                                                  2024-02-01 2024-02-01 2024-03-01 2024-05-01 2024-06-01]
                                   }).with_column(
                                     Polars.col("date").str.strptime(Polars::Datetime, "%Y-%m-%d")
                                   )
        dataset_config.merge!(datasource: df, target: :did_convert)
        dataset_config[:preprocessing_steps][:training].merge!(did_convert: { categorical: { categorical_min: 1,
                                                                                             encode_labels: true } })
        classification_dataset = EasyML::Data::Dataset.new(**dataset_config)
        classification_dataset.refresh!

        model.task = "classification"
        model.hyperparameters.objective = "binary:logistic"
        model.dataset = classification_dataset
        model.metrics = %w[accuracy_score precision_score recall_score f1_score]
        x_test, y_test = classification_dataset.test(split_ys: true)
        model.fit
        preds = model.predict(x_test)

        # Evaluate all classification metrics
        evaluation_metrics = model.evaluate(y_pred: preds, y_true: y_test)

        expect(evaluation_metrics[:accuracy_score]).to be_between(0, 1)
        expect(evaluation_metrics[:precision_score]).to be_between(0, 1)
        expect(evaluation_metrics[:recall_score]).to be_between(0, 1)
        expect(evaluation_metrics[:f1_score]).to be_between(0, 1)
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
        @time = EST.now
        Timecop.freeze(@time)

        model1 = build_model(name: "Test Model", is_live: true)
        model2 = build_model(name: "Test Model", is_live: false)
        model3 = build_model(name: "Test Model", is_live: false)
        other_model = build_model(name: "Other Model", is_live: true)

        model3.mark_live

        expect(model1.reload.is_live).to be false
        expect(model2.reload.is_live).to be false
        expect(model3.reload.is_live).to be true
        expect(other_model.reload.is_live).to be true
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

        old_versions_x = recent_models[0..1]
        recent_versions_x = recent_models[2..-1]

        expect(File).to exist(live_model_x.file.path)
        old_versions_x.each do |old_version|
          expect(File).to_not exist(old_version.file.path)
        end
        recent_versions_x.each do |recent_version|
          expect(File).to exist(recent_version.file.path)
        end

        # Create models with a different name
        build_model(name: "Model Y", is_live: true, created_at: 1.year.ago)
        recent_y = 7.times.map do |i|
          build_model(name: "Model Y", created_at: (6 - i).days.ago)
        end

        old_versions_y = recent_y[0..1]
        recent_versions_y = recent_y[2..-1]

        # Simulate training a new model X
        build_model(name: "Model X")

        # add least recent x to old versions x
        old_versions_x << recent_versions_x.shift
        expect(old_versions_x.count).to eq 3
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
      end
    end
  end
end
