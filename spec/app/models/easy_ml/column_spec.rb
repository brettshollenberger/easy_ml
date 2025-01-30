require "spec_helper"
require "support/model_spec_helper"

RSpec.describe EasyML::Column, type: :model do
  include ModelSpecHelper

  describe "#set_preprocessing_step_defaults" do
    let(:dataset) { loans_dataset }
    let(:annual_rev_column) { dataset.columns.find_by(name: "annual_revenue") }
    let(:business_name_column) { dataset.columns.find_by(name: "business_name") }
    let(:date_column) { dataset.columns.find_by(name: "date") }
    let(:loan_purpose_column) { dataset.columns.find_by(name: "loan_purpose") }
    let(:rev_column) { dataset.columns.find_by(name: "rev") }
    let(:state_column) { dataset.columns.find_by(name: "state") }

    context "with constant method" do
      let(:column) { annual_rev_column }
      it "sets default constant value" do
        column.update(
          preprocessing_steps: {
            training: { method: :constant },
          },
        )
        column.reload
        expect(column.preprocessing_steps.deep_symbolize_keys[:training][:params]).to include(constant: nil)
      end

      it "removes extra params" do
        column.update(
          preprocessing_steps: {
            training: {
              method: :constant,
              params: { constant: 5, extra: "value" },
            },
          },
        )
        column.reload
        expect(column.preprocessing_steps.deep_symbolize_keys[:training][:params].keys).to match_array([:constant])
      end
    end

    context "with categorical method" do
      let(:column) { loan_purpose_column }
      it "adds all missing required params with defaults" do
        column.update(
          preprocessing_steps: {
            training: { method: :categorical },
          },
        )
        column.reload
        expect(column.preprocessing_steps.deep_symbolize_keys[:training][:params]).to include(
          categorical_min: 100,
          one_hot: true,
          ordinal_encoding: false,
        )
      end

      it "keeps existing valid params" do
        column.update(
          preprocessing_steps: {
            training: {
              method: :categorical,
              params: {
                categorical_min: 50,
                one_hot: false,
                ordinal_encoding: true,
              },
            },
          },
        )
        column.reload
        params = column.preprocessing_steps.deep_symbolize_keys[:training][:params]
        expect(params).to include(
          categorical_min: 50,
          one_hot: false,
          ordinal_encoding: true,
        )
      end

      it "removes extra params" do
        column.update(
          preprocessing_steps: {
            training: {
              method: :categorical,
              params: {
                categorical_min: 50,
                one_hot: true,
                ordinal_encoding: false,
                extra: "value",
              },
            },
          },
        )
        column.reload
        expect(column.preprocessing_steps.deep_symbolize_keys[:training][:params].keys).to match_array([:categorical_min, :one_hot, :ordinal_encoding])
      end

      it "does not allow both one_hot and ordinal_encoding to be true" do
        column.update(
          preprocessing_steps: {
            training: {
              method: :categorical,
              params: {
                categorical_min: 50,
                one_hot: true,
                ordinal_encoding: true,
                extra: "value",
              },
            },
          },
        )
        column.reload
        expect(column.preprocessing_steps.deep_symbolize_keys[:training][:params]).to match(hash_including(
          one_hot: true,
          ordinal_encoding: false,
        ))
      end
    end

    context "with most_frequent method" do
      let(:column) { loan_purpose_column }
      it "allows one_hot and ordinal_encoding params" do
        column.update(
          preprocessing_steps: {
            training: {
              method: :most_frequent,
              params: {
                one_hot: true,
                ordinal_encoding: false,
              },
            },
          },
        )
        column.reload
        params = column.preprocessing_steps.deep_symbolize_keys[:training][:params]
        expect(params).to include(
          one_hot: true,
          ordinal_encoding: false,
        )
      end
    end

    context "with mean method" do
      let(:column) { rev_column }
      it "allows clip param" do
        column.update(
          preprocessing_steps: {
            training: {
              method: :mean,
              params: {
                clip: { min: 0, max: 100 },
              },
            },
          },
        )
        column.reload
        params = column.preprocessing_steps.deep_symbolize_keys[:training][:params]
        expect(params).to include(
          clip: { min: 0, max: 100 },
        )
      end
    end

    context "with median method" do
      let(:column) { rev_column }
      it "allows clip param" do
        column.update(
          preprocessing_steps: {
            training: {
              method: :median,
              params: {
                clip: { min: 0, max: 100 },
              },
            },
          },
        )
        column.reload
        params = column.preprocessing_steps.deep_symbolize_keys[:training][:params]
        expect(params).to include(
          clip: { min: 0, max: 100 },
        )
      end
    end

    context "with unknown method" do
      let(:column) { rev_column }
      it "handles unknown methods gracefully" do
        column.update(
          preprocessing_steps: {
            training: {
              method: :unknown,
              params: { some: "param" },
            },
          },
        )
        column.reload
        expect(column.preprocessing_steps.deep_symbolize_keys[:training][:params]).to be_empty
      end
    end

    context "with nil params" do
      let(:column) { rev_column }
      it "handles nil params gracefully" do
        column.update(
          preprocessing_steps: {
            training: { method: :constant },
          },
        )
        column.reload
        expect(column.preprocessing_steps.deep_symbolize_keys[:training][:params]).to include(constant: nil)
      end
    end
  end
end
