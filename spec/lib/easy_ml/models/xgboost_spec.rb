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

  describe "hyperparameter configurations" do
    describe "gbtree booster" do
      let(:model) do
        EasyML::Core::Models::XGBoost.new(
          model_type: :xgboost,
          root_dir: root_dir,
          task: :regression,
          dataset: dataset,
          hyperparameters: {
            booster: :gbtree,
            learning_rate: 0.1,
            max_depth: 6,
            n_estimators: 100,
            gamma: 0.1,
            min_child_weight: 1,
            subsample: 0.8,
            colsample_bytree: 0.8,
            objective: "reg:squarederror"
          }
        )
      end

      it "accepts gbtree-specific parameters", :focus do
        binding.pry
        expect(model.hyperparameters.to_h).to include(
          gamma: 0.1,
          min_child_weight: 1,
          subsample: 0.8,
          colsample_bytree: 0.8
        )
      end

      it "trains successfully with gbtree parameters" do
        expect { model.fit }.not_to raise_error
      end
    end

    describe "dart booster" do
      let(:model) do
        EasyML::Core::Models::XGBoost.new(
          model_type: :xgboost,
          root_dir: root_dir,
          task: :regression,
          dataset: dataset,
          hyperparameters: {
            booster: :dart,
            learning_rate: 0.1,
            max_depth: 6,
            n_estimators: 100,
            rate_drop: 0.1,
            skip_drop: 0.5,
            sample_type: "uniform",
            normalize_type: "tree",
            objective: "reg:squarederror"
          }
        )
      end

      it "accepts dart-specific parameters" do
        expect(model.hyperparameters.to_h).to include(
          rate_drop: 0.1,
          skip_drop: 0.5,
          sample_type: "uniform",
          normalize_type: "tree"
        )
      end

      it "trains successfully with dart parameters" do
        expect { model.fit }.not_to raise_error
      end
    end

    describe "gblinear booster" do
      let(:model) do
        EasyML::Core::Models::XGBoost.new(
          model_type: :xgboost,
          root_dir: root_dir,
          task: :regression,
          dataset: dataset,
          hyperparameters: {
            booster: :gblinear,
            learning_rate: 0.1,
            n_estimators: 100,
            updater: "coord_descent",
            feature_selector: "cyclic",
            objective: "reg:squarederror"
          }
        )
      end

      it "accepts gblinear-specific parameters" do
        expect(model.hyperparameters.to_h).to include(
          updater: "coord_descent",
          feature_selector: "cyclic"
        )
      end

      it "trains successfully with gblinear parameters" do
        expect { model.fit }.not_to raise_error
      end
    end

    describe "task-specific configurations" do
      describe "binary classification" do
        let(:model) do
          EasyML::Core::Models::XGBoost.new(
            model_type: :xgboost,
            root_dir: root_dir,
            task: :classification,
            dataset: dataset,
            hyperparameters: {
              booster: :binary,
              learning_rate: 0.1,
              max_depth: 6,
              n_estimators: 100,
              objective: "binary:logistic",
              scale_pos_weight: 2.0
            }
          )
        end

        it "accepts binary classification parameters" do
          expect(model.hyperparameters.to_h).to include(
            objective: "binary:logistic",
            scale_pos_weight: 2.0
          )
        end

        it "validates binary classification objective" do
          expect { model.fit }.not_to raise_error
        end
      end

      describe "multiclass classification" do
        let(:model) do
          EasyML::Core::Models::XGBoost.new(
            model_type: :xgboost,
            root_dir: root_dir,
            task: :classification,
            dataset: dataset,
            hyperparameters: {
              booster: :multiclass,
              learning_rate: 0.1,
              max_depth: 6,
              n_estimators: 100,
              objective: "multi:softmax",
              num_class: 3
            }
          )
        end

        it "accepts multiclass parameters" do
          expect(model.hyperparameters.to_h).to include(
            objective: "multi:softmax",
            num_class: 3
          )
        end

        it "validates multiclass objective" do
          expect { model.fit }.not_to raise_error
        end
      end

      describe "regression" do
        let(:model) do
          EasyML::Core::Models::XGBoost.new(
            model_type: :xgboost,
            root_dir: root_dir,
            task: :regression,
            dataset: dataset,
            hyperparameters: {
              booster: :regression,
              learning_rate: 0.1,
              max_depth: 6,
              n_estimators: 100,
              objective: "reg:squarederror"
            }
          )
        end

        it "accepts regression parameters" do
          expect(model.hyperparameters.to_h).to include(
            objective: "reg:squarederror"
          )
        end

        it "validates regression objective" do
          expect { model.fit }.not_to raise_error
        end
      end
    end

    describe "parameter validation" do
      it "raises error for invalid booster type" do
        expect do
          EasyML::Core::Models::XGBoost.new(
            model_type: :xgboost,
            root_dir: root_dir,
            task: :regression,
            dataset: dataset,
            hyperparameters: { booster: :invalid_booster }
          )
        end.to raise_error(/Unknown booster type/)
      end

      it "raises error for invalid objective" do
        model = EasyML::Core::Models::XGBoost.new(
          model_type: :xgboost,
          root_dir: root_dir,
          task: :regression,
          dataset: dataset,
          hyperparameters: {
            objective: "invalid_objective"
          }
        )
        expect { model.fit }.to raise_error(ArgumentError, /cannot use invalid_objective for regression task/)
      end
    end
  end
end
