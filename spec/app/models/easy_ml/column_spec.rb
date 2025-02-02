require "spec_helper"
require "support/model_spec_helper"

RSpec.describe EasyML::Column do
  include ModelSpecHelper

  let(:dataset) do
    titanic_dataset
  end

  describe "#lineage" do
    context "when column is in raw dataset" do
      let(:column) { dataset.columns.find_by(name: "Age") }

      it "includes 'Raw dataset' in lineage" do
        expect(column.lineage).to include("Raw dataset")
      end
    end

    context "when column is computed by a feature" do
      let(:feature) do
        dataset.features.create!(
          name: "FamilySize",
          feature_class: "FamilySizeFeature",
          needs_fit: true,
          feature_position: 1,
        )
      end

      it "includes computation source in lineage" do
        feature
        dataset.refresh!
        column = dataset.columns.find_by(name: "FamilySize")
        expect(column.lineage).to include("Computed by FamilySize")
      end
    end

    context "when column has preprocessing steps" do
      let(:column) { dataset.columns.find_by(name: "Age") }

      before do
        column.update(preprocessing_steps: { training: { method: "mean", params: { clip: true } } })
      end

      it "includes preprocessing steps in lineage" do
        expect(column.lineage).to include("Preprocessed using training")
      end
    end

    context "when column has multiple attributes" do
      let(:feature) do
        dataset.features.create!(
          name: "FamilySize",
          feature_class: "FamilySizeFeature",
          needs_fit: true,
          feature_position: 1,
        )
      end

      let(:column) do
        dataset.columns.create!(
          name: "FamilySize",
          computed_by: "FamilySize",
          is_computed: true,
          preprocessing_steps: { training: { method: "mean", params: { clip: true } } },
        )
      end

      it "includes all relevant information in lineage" do
        lineage = column.lineage
        expect(lineage).to include("Computed by FamilySize")
        expect(lineage).to include("Preprocessed using training")
        expect(lineage.length).to eq(2)
      end
    end
  end

  describe "#present_in_raw_dataset" do
    context "when column exists in raw dataset" do
      let(:column) { dataset.columns.find_by(name: "Age") }

      it "returns true" do
        expect(column.present_in_raw_dataset).to be true
      end
    end

    context "when column is computed" do
      let(:feature) do
        dataset.features.create!(
          name: "FamilySize",
          feature_class: "FamilySizeFeature",
          needs_fit: true,
          feature_position: 1,
        )
      end

      let(:column) do
        dataset.columns.create!(
          name: "FamilySize",
          computed_by: "FamilySize",
          is_computed: true,
        )
      end

      it "returns false" do
        expect(column.present_in_raw_dataset).to be false
      end
    end
  end

  describe "computed columns" do
    let(:feature) do
      dataset.features.create!(
        name: "FamilySize",
        feature_class: "FamilySizeFeature",
        needs_fit: true,
        feature_position: 1,
      )
    end

    let(:column) do
      dataset.columns.create!(
        name: "FamilySize",
        computed_by: "FamilySize",
        is_computed: true,
      )
    end

    it "is marked as computed" do
      expect(column.is_computed).to be true
      expect(column.computed_by).to eq("FamilySize")
    end

    context "when column is not computed" do
      let(:column) { dataset.columns.find_by(name: "Age") }

      it "is not marked as computed" do
        expect(column.is_computed).to be false
        expect(column.computed_by).to be_nil
      end
    end
  end

  describe "scopes" do
    describe ".required" do
      let(:feature) do
        dataset.features.create!(
          name: "FamilySize",
          feature_class: "FamilySizeFeature",
          needs_fit: true,
          feature_position: 1,
        )
      end

      before do
        # Create computed column via feature
        feature
        # Create preprocessed column
        dataset.columns.find_by(name: "Age").update(
          preprocessing_steps: { training: { method: "mean", params: { clip: { min: 0, max: 100 } } } },
        )
        dataset.refresh
      end

      it "includes only raw, unprocessed columns" do
        # dataset.refresh
        required_columns = dataset.columns.required

        # Should include raw, unprocessed columns like PassengerId
        expect(required_columns).to include(dataset.columns.find_by(name: "PassengerId"))

        # Should not include computed columns
        expect(required_columns).not_to include(dataset.columns.find_by(name: "FamilySize"))

        # Should not include preprocessed columns
        expect(required_columns).not_to include(dataset.columns.find_by(name: "Age"))
      end
    end
  end
end
