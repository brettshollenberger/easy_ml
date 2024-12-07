require "spec_helper"

RSpec.describe EasyML::Core::ModelEvaluator do
  let(:y_true) { [3.0, -0.5, 2.0, 7.0] }
  let(:y_pred) { [2.5, 0.0, 2.0, 8.0] }
  let(:x_true) { [1.0, 2.0, 3.0, 4.0] } # For evaluators that might need input features

  describe ".evaluate" do
    let(:model) { double("Model", metrics: metrics) }
    let(:metrics) { ["mean_absolute_error"] }

    it "calculates mean absolute error" do
      result = described_class.evaluate(
        model: model,
        y_pred: y_pred,
        y_true: y_true
      )

      expect(result[:mean_absolute_error]).to be_within(0.01).of(0.5)
    end

    context "with multiple metrics" do
      let(:metrics) { %w[mean_absolute_error mean_squared_error r2_score] }

      it "calculates all specified metrics" do
        result = described_class.evaluate(
          model: model,
          y_pred: y_pred,
          y_true: y_true
        )

        expect(result.keys).to match_array(%i[mean_absolute_error mean_squared_error r2_score])
        expect(result[:mean_absolute_error]).to be_within(0.01).of(0.5)
        expect(result[:mean_squared_error]).to be_within(0.01).of(0.375)
        expect(result[:r2_score]).to be_within(0.01).of(0.94)
      end
    end

    context "with classification metrics" do
      let(:y_true) { [1, 0, 1, 1, 0] }
      let(:y_pred) { [1, 0, 1, 0, 0] }
      let(:metrics) { %w[accuracy_score precision_score recall_score f1_score] }

      it "calculates classification metrics correctly" do
        result = described_class.evaluate(
          model: model,
          y_pred: y_pred,
          y_true: y_true
        )

        expect(result[:accuracy_score]).to eq(0.8)
        expect(result[:precision_score]).to eq(1.0)
        expect(result[:recall_score]).to be_within(0.01).of(0.667)
        expect(result[:f1_score]).to be_within(0.01).of(0.8)
      end
    end

    context "with custom evaluator" do
      before do
        class CustomEvaluator
          include EasyML::Core::Evaluators::BaseEvaluator

          def evaluate(y_pred:, y_true:, x_true: nil)
            y_pred.sum / y_true.sum
          end

          def metric
            :custom_metric
          end
        end

        described_class.register(:custom_metric, CustomEvaluator, :regression)
      end

      it "uses custom evaluator when specified" do
        result = described_class.evaluate(
          model: model,
          y_pred: y_pred,
          y_true: y_true,
          evaluator: { metric: :custom_metric, max: 2 }
        )

        expect(result[:custom_metric]).to be_within(0.01).of(1.087)
      end
    end
  end

  describe "input handling" do
    let(:metrics) { ["mean_absolute_error"] }
    let(:model) { double("Model", metrics: metrics) }

    it "handles Polars DataFrame inputs" do
      df_pred = Polars::DataFrame.new({ "prediction" => y_pred })
      df_true = Polars::DataFrame.new({ "actual" => y_true })

      result = described_class.evaluate(
        model: model,
        y_pred: df_pred,
        y_true: df_true
      )

      expect(result[:mean_absolute_error]).to be_within(0.01).of(0.5)
    end

    it "raises error for mismatched sizes" do
      expect do
        described_class.evaluate(
          model: model,
          y_pred: [1, 2],
          y_true: [1, 2, 3]
        )
      end.to raise_error(ArgumentError, "Different sizes")
    end
  end
end
