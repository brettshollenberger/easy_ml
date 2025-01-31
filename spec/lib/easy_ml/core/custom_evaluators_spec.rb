require "spec_helper"
require_rails_files
require "support/model_spec_helper"

RSpec.describe "Custom Evaluators" do
  include ModelSpecHelper

  class TestWeightedMAE < EasyML::Evaluators::Base
    def calculate(y_pred, y_true)
      y_pred = y_pred.to_a
      y_true = y_true.to_a
      weights = compute_weights(y_true)

      weighted_errors = y_pred.zip(y_true, weights).map do |pred, true_val, weight|
        ((pred - true_val).abs * weight).to_f
      end

      weighted_errors.sum / weights.sum
    end

    def direction
      :minimize
    end

    def self.description
      "Test evaluator: MAE weighted by true value magnitude"
    end

    def self.supports_task?(task)
      true
    end

    private

    def compute_weights(y_true)
      y_min = y_true.min
      y_max = y_true.max
      range = y_max - y_min

      y_true.map do |val|
        1.0 + ((val - y_min) / range) if range > 0
      end
    end
  end

  before(:all) do
    # Register our test evaluator
    EasyML::Core::ModelEvaluator.register(
      "test_weighted_mae",
      TestWeightedMAE,
      [:regression],
      ["test_wmae"]
    )
  end

  describe "Custom Evaluator Registration" do
    it "registers custom evaluators with the evaluator system" do
      evaluator = EasyML::Core::ModelEvaluator.get("test_weighted_mae")
      expect(evaluator).to eq(TestWeightedMAE)
    end

    it "supports aliases for custom evaluators" do
      evaluator = EasyML::Core::ModelEvaluator.get("test_wmae")
      expect(evaluator).to eq(TestWeightedMAE)
    end

    it "respects task support restrictions" do
      evaluator = TestWeightedMAE.new
      expect(TestWeightedMAE.supports_task?(:regression)).to be true
      expect(TestWeightedMAE.supports_task?(:classification)).to be true
    end
  end

  describe "Custom Evaluator Behavior" do
    let(:evaluator) { TestWeightedMAE.new }

    it "implements the required interface" do
      expect(evaluator).to respond_to(:calculate)
      expect(evaluator).to respond_to(:direction)
      expect(TestWeightedMAE).to respond_to(:description)
      expect(TestWeightedMAE).to respond_to(:supports_task?)
    end

    it "calculates weighted metrics correctly" do
      y_pred = [1.0, 8.0]
      y_true = [2.0, 1000.0]

      # First prediction is off by 1, second is off by 3
      # and gets double weight, so weighted MAE should be higher
      score = evaluator.calculate(y_pred, y_true)

      expect(score).to be > 496.5 # Regular MAE
    end
  end

  describe "Integration with Tuner" do
    let(:model) { titanic_model }

    it "accepts custom evaluators in tuner initialization" do
      model.assign_attributes(evaluator: { metric: :test_weighted_mae, max: 10 })
      model.save

      tuner = EasyML::Core::Tuner.new(
        model: model,
        objective: "mean_absolute_error", # Can't use test_weighted_mae as the objective, only as tuner evaluator
        evaluator: model.evaluator,
        task: :classification,
        config: {
          n_estimators: {
            min: 1,
            max: 1,
          },
        },
      )

      expect(tuner.direction.to_sym).to eq(:minimize)
      result = tuner.tune_once
      expect(result.key?(:test_weighted_mae)).to be true
    end
  end
end
