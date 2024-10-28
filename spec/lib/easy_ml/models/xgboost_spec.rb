require "spec_helper"
require "support/model_spec_helper"

RSpec.describe EasyML::Core::Models::XGBoost do
  include ModelSpecHelper

  describe "XGBoost" do
    let(:model) do
      EasyML::Core::Models::XGBoost.new(
        model_type: :xgboost,
        root_dir: root_dir,
        task: task,
        dataset: dataset,
        hyperparameters: {
          learning_rate: 0.05,
          max_depth: 8,
          objective: objective,
          n_estimators: 1
        }
      )
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
        dataset.refresh!
        x_test, = dataset.test(split_ys: true)
        model.fit
        preds = model.predict(x_test)
        expect(preds).to all(be_a Numeric)
      end

      it "evaluates regression predictions" do
        dataset.refresh!
        xs, ys = dataset.data(split_ys: true)
        model.metrics = %w[mean_absolute_error mean_squared_error root_mean_squared_error r2_score]
        model.fit
        preds = model.predict(xs)

        evaluation_metrics = model.evaluate(y_pred: preds, y_true: ys)

        expect(evaluation_metrics[:mean_absolute_error]).to be_between(0, 1_000)
        expect(evaluation_metrics[:mean_squared_error]).to be_between(0, 5_000_000)
        expect(evaluation_metrics[:root_mean_squared_error]).to be_between(0, Float::INFINITY)
        expect(evaluation_metrics[:r2_score]).to be_between(-Float::INFINITY, 1)
      end

      describe "classification" do
        let(:task) do
          :classification
        end
        let(:objective) do
          "binary:logistic"
        end
        let(:target) do
          :did_convert
        end
        let(:df) do
          super().with_columns([
                                 Polars::Series.new("state", %w[VIRGINIA INDIANA WYOMING PA WA MN UT CA DE FL]),
                                 Polars::Series.new("did_convert",
                                                    %w[converts not_converts converts converts converts not_converts
                                                       not_converts converts converts not_converts]),
                                 Polars::Series.new("passive_rev", [0, 30, 0, 0, 0, 50, 60, 0, 0, 70])
                               ])
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
        let(:drop_columns) do
          super() << %w[rev]
        end

        it "evaluates classification predictions" do
          dataset.refresh!
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
  end
end
