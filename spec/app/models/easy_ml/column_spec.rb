require "spec_helper"
require "support/model_spec_helper"

RSpec.describe EasyML::Column do
  include ModelSpecHelper

  let(:dataset) do
    titanic_dataset
  end

  let(:feature) do
    dataset.save
    dataset.features.create!(
      name: "FamilySize",
      feature_class: "FamilySizeFeature",
      needs_fit: true,
      feature_position: 1,
    )
  end

  describe "Datatype & PolarsDatatype" do
    let(:column) { dataset.columns.find_by(name: "Age") }

    it "returns correct datatype" do
      expect(column.datatype.to_sym).to eq(:float)
    end

    it "returns correct PolarsDatatype" do
      expect(column.polars_datatype).to eq(Polars::Float64)
    end

    it "returns correct datatype for features" do
      feature
      dataset.refresh
      expect(dataset.columns.find_by(name: "FamilySize").datatype.to_sym).to eq(:integer)
    end
  end

  describe "#statistics" do
    context "Integer column" do
      let(:column) { dataset.columns.find_by(name: "Age") }

      it "returns statistics for the column" do
        dataset.refresh
        stats = column.reload.statistics
        expect(stats.key?(:raw)).to be true
        expect(stats.key?(:processed)).to be true
        expect(stats.dig(:raw, :num_rows)).to eq 891
        expect(stats.dig(:raw, :null_count)).to eq 177
        expect(stats.dig(:raw, :mean)).to be_within(0.1).of(29.84)
        expect(stats.dig(:raw, :median)).to be_within(0.1).of(28)
        expect(stats.dig(:raw, :min)).to be_within(0.1).of(0.75)
        expect(stats.dig(:raw, :max)).to be_within(0.1).of(71)
        expect(stats.dig(:raw, :std)).to be_within(0.1).of(14.7)
      end
    end

    context "Categorical column" do
      let(:column) { dataset.columns.find_by(name: "Sex") }

      it "returns statistics for the column" do
        dataset.refresh

        stats = column.reload.statistics
        expect(stats.key?(:raw)).to be true
        expect(stats.key?(:processed)).to be true
        expect(stats.dig(:raw, :num_rows)).to eq 891
        expect(stats.dig(:raw, :null_count)).to eq 0
        expect(stats.dig(:raw, :unique_count)).to eq 2
        expect(stats.dig(:raw, :most_frequent_value)).to eq "male"
        expect(stats.dig(:raw, :allowed_categories)).to eq %w[female male]
      end

      it "ordinal encodes" do
        column.update(preprocessing_steps: {
                        training: {
                          method: :categorical,
                          params: {
                            ordinal_encoding: true,
                          },
                        },
                      })
        dataset.refresh
        stats = column.reload.statistics
        expect(column.decode_labels([0, 1])).to eq(%w[female male])
      end

      it "one_hot encodes" do
        column.update(preprocessing_steps: {
                        training: {
                          method: :categorical,
                          params: {
                            one_hot: true,
                          },
                        },
                      })
        dataset.refresh
        column.reload
        expect(column.raw.data.columns.sort).to eq(["Sex"])
        expect(column.processed.data.columns.sort).to eq(%w[Sex_female Sex_male Sex_other])
      end
    end

    context "String column" do
      let(:column) { dataset.columns.find_by(name: "Name") }

      it "returns statistics for the column" do
        dataset.refresh
        stats = column.reload.statistics
        expect(stats.key?(:raw)).to be true
        expect(stats.key?(:processed)).to be true
        expect(stats.dig(:raw, :num_rows)).to eq 891
        expect(stats.dig(:raw, :null_count)).to eq 0
        expect(stats.dig(:raw, :unique_count)).to eq 891
      end
    end

    context "Datetime column" do
      let(:dataset) { loans_dataset }
      let(:column) do
        col = dataset.columns.find_by(name: "date")
        col.update(hidden: false, is_date_column: true)
        col
      end

      it "returns statistics for the column" do
        column
        dataset.refresh
        stats = column.reload.statistics
        expect(stats.key?(:raw)).to be true
        expect(stats.key?(:processed)).to be true
        expect(stats.dig(:raw, :num_rows)).to eq 10
        expect(stats.dig(:raw, :null_count)).to eq 0
        expect(stats.dig(:raw, :unique_count)).to eq 9
        expect(
          DateTime.parse(stats.dig(:raw, :last_value)).strftime("%Y-%m-%d")
        ).to eq "2024-01-01"
      end
    end

    xcontext "Null column" do
      let(:dataset) { null_dataset }
      let(:column) { dataset.columns.find_by(name: "null_col") }

      it "returns statistics for the column" do
        dataset.refresh
        stats = column.reload.statistics
        expect(stats.key?(:raw)).to be true
        expect(stats.key?(:processed)).to be true
        expect(stats.dig(:raw, :num_rows)).to eq 1
        expect(stats.dig(:raw, :null_count)).to eq 1
        expect(stats.dig(:raw, :last_value)).to be_nil
      end
    end

    context "Entire dataset" do
      it "learns statistics for the entire dataset" do
        dataset.learn_statistics
        expect(dataset.statistics.dig(:raw, :Age, :mean)).to be_within(0.1).of(29.84)
        expect(dataset.statistics.dig(:processed, :Sex, :unique_count)).to eq(2)
        expect(dataset.statistics.dig(:raw, :Name, :unique_count)).to eq(891)
      end
    end
  end

  describe "#lineage" do
    context "when column is in raw dataset" do
      let(:column) { dataset.columns.find_by(name: "Age") }

      it "includes 'Raw dataset' in lineage" do
        expect(column.lineages.first.key.to_sym).to eq(:raw_dataset)
      end
    end

    context "when column is computed by a feature" do
      it "includes computation source in lineage" do
        feature
        dataset.refresh!
        column = dataset.columns.find_by(name: "FamilySize")
        expect(column.lineages.map(&:key).map(&:to_sym)).to include(:computed_by_feature)
        expect(column.lineages.map(&:description)).to include("Computed by FamilySize")
      end
    end

    context "when column has preprocessing steps" do
      let(:column) { dataset.columns.find_by(name: "Age") }

      before do
        column.update(preprocessing_steps: { training: { method: "mean", params: { clip: { min: 0, max: 20 } } } })
        dataset.columns.find_by(name: "SibSp").update(preprocessing_steps: { training: { method: "mean",
                                                                                       params: { clip: { min: 0,
                                                                                                        max: 1 } } } })
      end

      it "includes preprocessing steps in lineage" do
        expect(column.lineages.map(&:key).map(&:to_sym)).to include(:preprocessed)
      end

      it "queries based on columns containing clip" do
        expect(EasyML::Column.has_clip.map(&:id)).to include(column.id)
      end

      it "applies clip to statistics & processed datasets" do
        dataset.refresh
        expect(dataset.columns.find_by(name: "Age").statistics.dig(:raw, :max)).to eq(20)
        expect(dataset.columns.find_by(name: "Age").statistics.dig(:raw, :median)).to eq(20)
        expect(dataset.columns.find_by(name: "SibSp").statistics.dig(:raw, :max)).to eq(1)

        expect(dataset.processed.data(lazy: true).select("Age").max.collect.to_a.first.dig("Age")).to eq(20)
        expect(dataset.processed.data(lazy: true).select("SibSp").max.collect.to_a.first.dig("SibSp")).to eq(1)
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
        feature
        dataset.columns.create!(
          name: "FamilySize",
          preprocessing_steps: { training: { method: "mean", params: { clip: { min: 0, max: 100 } } } },
        )
      end

      it "includes all relevant information in lineage" do
        column
        dataset.refresh
        lineage = column.lineages

        expect(lineage.detect do |l|
          l.key.to_sym == :computed_by_feature
        end.description).to include("Computed by FamilySize")
        expect(lineage.detect do |l|
          l.key.to_sym == :preprocessed
        end.description).to include("Preprocessed using Clip, Mean imputation")
        expect(lineage.length).to eq(2)
      end
    end
  end

  describe "#in_raw_dataset?" do
    context "when column exists in raw dataset" do
      let(:column) { dataset.columns.find_by(name: "Age") }

      it "returns true" do
        expect(column.in_raw_dataset?).to be true
      end
    end

    context "when column is computed" do
      let(:column) do
        feature
        dataset.refresh
        dataset.columns.find_by(name: "FamilySize")
      end

      it "returns false" do
        expect(column.in_raw_dataset?).to be false
      end
    end
  end

  describe "computed columns" do
    let(:column) do
      feature
      dataset.refresh
      dataset.columns.find_by(name: "FamilySize")
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

  describe "Changing column datatypes" do
    describe "Changing from string to categorical" do
      let(:column) { dataset.columns.find_by(name: "Sex") }

      it "updates the underlying datasource representation" do
        column.update(datatype: "string")
        expect(dataset.raw.data["Sex"].dtype).to eq(Polars::Utf8)

        column.update(datatype: "categorical")
        expect(dataset.raw.data["Sex"].dtype).to eq(Polars::Categorical)
      end
    end

    describe "Changing from string to int/float", :focus do
      let(:column) { dataset.columns.find_by(name: "Age") }

      it "updates the underlying datasource representation" do
        column.update(datatype: "string")
        expect(dataset.raw.data["Age"].dtype).to eq(Polars::Utf8)

        column.update(datatype: "integer")
        expect(dataset.raw.data["Age"].dtype).to eq(Polars::Int64)

        column.update(datatype: "float")
        expect(dataset.raw.data["Age"].dtype).to eq(Polars::Float64)

        column.update(datatype: "null")
        expect(column.errors.map(&:message)).to include("Can't cast from float to null")
      end
    end
  end
end
