require "spec_helper"
require "support/model_spec_helper"

RSpec.describe EasyML::Core::Models::XGBoost do
  include ModelSpecHelper
  let(:model_class) do
    EasyML::Core::Models::XGBoost
  end

  describe "XGBoost" do
    let(:xgb) { ::XGBoost }

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

        evaluation_metrics = model.evaluate(y_pred: preds, y_true: ys)

        expect(evaluation_metrics[:mean_absolute_error]).to be_between(784, 785)
        expect(evaluation_metrics[:mean_squared_error]).to be_between(4_793_806, 4_793_807)
        expect(evaluation_metrics[:root_mean_squared_error]).to be_between(2189, 2190)
        expect(evaluation_metrics[:r2_score]).to be_between(-Float::INFINITY, 1)
      end

      describe "classification" do
        let(:task) do
          :classification
        end
        let(:objective) do
          "binary:logistic"
        end

        let(:df) do
          Polars::DataFrame.new({
                                  "id" => [1, 2, 3, 4, 5, 6, 7, 8, 9, 10],
                                  "business_name" => ["Business A", "Business B", "Business C", "Business D", "Business E", "Business F",
                                                      "Business G", "Business H", "Business I", "Business J"],
                                  "annual_revenue" => [1000, 2000, 3000, 4000, 5000, 6000, 7000, 8000, 9000,
                                                       10_000],
                                  "loan_purpose" => %w[payroll payroll payroll expansion payroll inventory equipment
                                                       marketing equipment marketing],
                                  "state" => %w[VIRGINIA INDIANA WYOMING PA WA MN UT CA DE FL],
                                  "did_convert" => %w[converts not_converts converts converts converts
                                                      not_converts not_converts converts converts not_converts],
                                  "rev" => [1_000, 0, 2_000, 3_000, 4_000, 0, 0, 5_000, 6_000, 0],
                                  "passive_rev" => [0, 30, 0, 0, 0, 50, 60, 0, 0, 70],
                                  "date" => %w[2021-01-01 2021-05-01 2022-01-01 2023-01-01 2024-01-01
                                               2024-02-01 2024-02-01 2024-03-01 2024-05-01 2024-06-01]
                                }).with_column(
                                  Polars.col("date").str.strptime(Polars::Datetime, "%Y-%m-%d")
                                )
        end
        let(:target) do
          :did_convert
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
              },
              did_convert: {
                categorical: {
                  categorical_min: 1,
                  encode_labels: true
                }
              }
            }
          }
        end

        it "evaluates classification predictions" do
          x_test, y_test = dataset.test(split_ys: true)
          model.fit
          model.metrics = %w[accuracy_score precision_score recall_score f1_score]
          preds = model.predict(x_test)

          # Evaluate all classification metrics
          evaluation_metrics = model.evaluate(y_pred: preds, y_true: y_test)

          expect(evaluation_metrics[:accuracy_score]).to be_between(0, 1)
          expect(evaluation_metrics[:precision_score]).to be_between(0, 1)
          expect(evaluation_metrics[:recall_score]).to be_between(0, 1)
          expect(evaluation_metrics[:f1_score]).to be_between(0, 1)
        end

        it "decodes labels" do
          x_test, = dataset.test(split_ys: true)
          model.metrics = %w[accuracy_score precision_score recall_score f1_score]
          model.fit
          preds_orig = model.predict(x_test)
          preds = model.decode_labels(preds_orig)
          expect(preds_orig).to eq([0, 0])
          expect(preds).to eq(%w[converts converts])
        end

        describe "Custom evaluators" do
          xit "uses custom evaluators" do
            model.metrics = %w[accuracy_score precision_score recall_score f1_score]
            model.metrics << CustomEvaluator
            x_test, y_test = dataset.test(split_ys: true)
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

        loaded_model = EasyML::Core::Models::XGBoost.new(file: model.file)
        loaded_model.load

        expect(loaded_model.predict(dataset.test(split_ys: true).first)).to eq(model.predict(dataset.test(split_ys: true).first))
      end

      it "works on S3 storage", fog: true do
        s3_url = "https://s3-bucket.amazonaws.com/model.json"
        allow_any_instance_of(CarrierWave::Storage::Fog::File).to receive(:url).and_return(s3_url)

        model.name = "S3 Model"
        model.metrics = ["mean_absolute_error"]
        model.fit
        model.save

        loaded_model = EasyML::Core::Models::XGBoost.new(file: model.file)

        allow(loaded_model.file).to receive(:download) do |&block|
          File.open(model.file.path, "rb", &block)
        end

        loaded_model.load
        expect(loaded_model.predict(dataset.test(split_ys: true).first)).to eq(model.predict(dataset.test(split_ys: true).first))
      end
    end
  end
end
