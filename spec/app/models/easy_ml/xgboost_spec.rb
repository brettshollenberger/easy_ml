require "spec_helper"
require "support/model_spec_helper"

RSpec.describe "EasyML::Models::XGBoost" do
  include ModelSpecHelper

  before(:each) do
    EasyML::Cleaner.clean
  end
  after(:each) do
    EasyML::Cleaner.clean
  end

  describe "XGBoost" do
    let(:booster) do
      :gbtree
    end
    let(:model) do
      EasyML::Model.new(
        name: "My Model",
        model_type: "xgboost",
        task: task,
        dataset: dataset,
        objective: objective,
        hyperparameters: {
          booster: booster,
          learning_rate: 0.05,
          max_depth: 8,
          objective: objective,
          n_estimators: 1,
        },
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

    describe "#model_changed?" do
      it "returns false when no model is fit" do
        expect(model.model_changed?).to be false
      end

      it "returns true when model file is fit but not yet saved" do
        model.fit
        expect(model.model_changed?).to be true
      end

      context "with saved model" do
        before do
          mock_s3_upload
          model.fit
          model.save
        end

        it "returns true when model has been fit but not deployed" do
          expect(model.model_changed?).to be true
        end

        it "returns true when model parameters have changed" do
          # Fit a new model with different hyperparameters
          model.hyperparameters.max_depth = model.hyperparameters.max_depth + 1
          model.hyperparameters.learning_rate = 0.01
          model.hyperparameters.n_estimators = 10
          model.fit

          expect(model.model_changed?).to be true
        end
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
        let(:booster) do
          :gbtree
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
                                 Polars::Series.new("passive_rev", [0, 30, 0, 0, 0, 50, 60, 0, 0, 70]),
                               ])
        end
        let(:preprocessing_steps) do
          {
            training: {
              annual_revenue: {
                median: true,
                clip: { min: 0, max: 1_000_000 },
              },
              loan_purpose: {
                categorical: {
                  categorical_min: 2,
                  one_hot: true,
                },
              },
              did_convert: {
                categorical: {
                  categorical_min: 1,
                  ordinal_encoding: true,
                },
              },
            },
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
          dataset.refresh
          x_test, = dataset.test(split_ys: true)
          model.metrics = %w[accuracy_score precision_score recall_score f1_score]
          model.fit
          preds_orig = model.predict(x_test)
          preds = model.decode_labels(preds_orig)
          expect(preds_orig).to eq([0, 0])
          expect(preds).to eq(%w[converts converts])
        end
      end
    end

    describe "#train_in_batches" do
      let(:model) do
        titanic_model
      end

      it "produces same predictions as regular fit", :focus do
        # Get test data
        titanic_dataset.refresh
        model.reload
        model.hyperparameters.n_estimators = 50
        model.hyperparameters.early_stopping_rounds = 10
        model.save
        x_test, = titanic_dataset.test(split_ys: true)

        # Train model normally
        regular_model = model.dup
        regular_model.fit
        regular_evals = regular_model.evaluate

        # Train model in batches
        batch_model = model.dup
        batch_model.hyperparameters.n_estimators = 50
        batch_model.hyperparameters.early_stopping_rounds = 10
        batch_model.fit_in_batches(batch_size: 50, batch_overlap: 5)
        batch_evals = batch_model.evaluate

        # Compare metrics
        expect(batch_evals[:accuracy_score]).to be_within(0.1).of(regular_evals[:accuracy_score])
        expect(batch_evals[:precision_score]).to be_within(0.1).of(regular_evals[:precision_score])
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
        EasyML::Model.new(
          model_type: "xgboost",
          task: :regression,
          dataset: dataset,
          hyperparameters: {
            early_stopping_rounds: 15,
            booster: :gbtree,
            learning_rate: 0.1,
            max_depth: 6,
            n_estimators: 1,
            gamma: 0.1,
            min_child_weight: 1,
            subsample: 0.8,
            colsample_bytree: 0.8,
            objective: "reg:squarederror",
          },
        )
      end

      it "accepts gbtree-specific parameters" do
        expect(model.hyperparameters.to_h.symbolize_keys).to match(hash_including({
                                                                                    gamma: 0.1,
                                                                                    min_child_weight: 1,
                                                                                    subsample: 0.8,
                                                                                    colsample_bytree: 0.8,
                                                                                  }))
        m = EasyML::Model.create(
          name: "My Model",
          dataset: dataset,
          task: :classification,
          model_type: "xgboost",
          hyperparameters: {
            booster: :gbtree,
            learning_rate: 1.0,
            gamma: 0.01,
          },
        )
        m = EasyML::Model.find(m.id)
        expect(m.hyperparameters.booster).to eq "gbtree"
        expect(m.hyperparameters.gamma).to eq 0.01
        expect(m.hyperparameters.class).to eq EasyML::Models::Hyperparameters::XGBoost::GBTree
      end

      it "accepts early stopping rounds" do
        expect(::XGBoost).to receive(:train).with(any_args, hash_including({ early_stopping_rounds: 15 }))
        model.fit
      end

      it "trains successfully with gbtree parameters" do
        expect { model.fit }.not_to raise_error
      end
    end

    describe "dart booster" do
      let(:model) do
        EasyML::Model.new(
          model_type: "xgboost",
          task: :regression,
          dataset: dataset,
          hyperparameters: {
            booster: :dart,
            learning_rate: 0.1,
            max_depth: 6,
            n_estimators: 1,
            rate_drop: 0.1,
            skip_drop: 0.5,
            sample_type: "uniform",
            normalize_type: "tree",
            objective: "reg:squarederror",
          },
        )
      end

      it "accepts dart-specific parameters" do
        expect(model.hyperparameters.to_h.symbolize_keys).to match(hash_including({
                                                                                    rate_drop: 0.1,
                                                                                    skip_drop: 0.5,
                                                                                    sample_type: "uniform",
                                                                                    normalize_type: "tree",
                                                                                  }))
      end

      it "trains successfully with dart parameters" do
        expect { model.fit }.not_to raise_error
      end
    end

    describe "gblinear booster" do
      let(:model) do
        EasyML::Model.new(
          model_type: "xgboost",
          task: :regression,
          dataset: dataset,
          hyperparameters: {
            booster: :gblinear,
            learning_rate: 0.1,
            n_estimators: 1,
            updater: "coord_descent",
            feature_selector: "cyclic",
            objective: "reg:squarederror",
          },
        )
      end

      it "accepts gblinear-specific parameters" do
        expect(model.hyperparameters.to_h.symbolize_keys).to match(hash_including({
                                                                                    updater: "coord_descent",
                                                                                    feature_selector: "cyclic",
                                                                                  }))
      end

      it "trains successfully with gblinear parameters" do
        expect { model.fit }.not_to raise_error
      end
    end

    describe "parameter validation" do
      it "raises error for invalid booster type" do
        expect do
          model = EasyML::Model.new(
            model_type: "xgboost",
            task: :regression,
            dataset: dataset,
            hyperparameters: { booster: :invalid_booster },
          )
          model.hyperparameters
        end.to raise_error(/Unknown booster type/)
      end

      it "raises error for invalid objective" do
        model = EasyML::Model.new(
          model_type: "xgboost",
          task: :regression,
          dataset: dataset,
          objective: "invalid_objective",
          hyperparameters: {
            booster: :gbtree,
          },
        )
        expect { model.fit }.to raise_error(ArgumentError, /cannot use invalid_objective for regression task/)
      end
    end
  end
end
