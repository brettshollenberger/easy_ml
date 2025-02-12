require "spec_helper"
require "support/model_spec_helper"

RSpec.describe EasyML::Import::Dataset do
  include ModelSpecHelper

  let(:dataset) { titanic_dataset }
  let(:config) do
    {
      "dataset" => {
        "name" => "Different Dataset Name",  # Name doesn't need to match
        "description" => "The titanic dataset",
        "datasource" => {
          "name" => "New Titanic Source",
          "datasource_type" => "s3",
          "configuration" => {
            "s3_bucket" => "new-titanic",
            "s3_prefix" => "data/",
          },
        },
        "columns" => [
          {
            "name" => "PassengerId",
            "description" => "Updated Passenger ID",
            "datatype" => "Int64",
            "polars_datatype" => "Polars::Int64",
            "is_date_column" => false,
            "is_target" => false,
            "hidden" => false,
            "drop_if_null" => true,
            "preprocessing_steps" => {
              "training" => {
                "method" => "mean",
                "params" => {},
              },
            },
          },
          {
            "name" => "NewColumn",
            "description" => "A new column not in original dataset",
            "datatype" => "String",
            "polars_datatype" => "Polars::String",
            "is_date_column" => false,
            "is_target" => false,
            "hidden" => false,
          },
        ],
      },
    }
  end

  before(:each) do
    EasyML::Cleaner.clean
    dataset.refresh
  end

  describe ".from_config" do
    context "when creating a new dataset" do
      it "creates a new dataset with the specified configuration" do
        new_dataset = described_class.from_config(config, action: :create)

        expect(new_dataset).to be_persisted
        expect(new_dataset.name).to eq("Different Dataset Name")
        expect(new_dataset.description).to eq("The titanic dataset")

        # Verifies datasource is created
        expect(new_dataset.datasource.name).to eq("New Titanic Source")
        expect(new_dataset.datasource.datasource_type).to eq("s3")
        expect(new_dataset.datasource.configuration["s3_bucket"]).to eq("new-titanic")

        # Verifies all columns are created
        expect(new_dataset.columns.count).to eq(2)
        passenger_id = new_dataset.columns.find_by(name: "PassengerId")
        expect(passenger_id.description).to eq("Updated Passenger ID")
        expect(passenger_id.drop_if_null).to be true

        new_column = new_dataset.columns.find_by(name: "NewColumn")
        expect(new_column).to be_present
        expect(new_column.datatype).to eq("String")
      end

      it "raises an error if action is not specified" do
        expect {
          described_class.from_config(config)
        }.to raise_error(ArgumentError, /Action must be specified/)
      end
    end

    context "when updating an existing dataset" do
      let(:update_config) do
        {
          "dataset" => {
            "name" => "Completely Different Name",  # Name in config doesn't matter
            "description" => "Updated description",
            "columns" => [
              {
                "name" => "PassengerId",
                "description" => "Modified Passenger ID",
                "datatype" => "Int64",
                "is_target" => true,
                "drop_if_null" => true,
              },
              {
                "name" => "NewColumn",
                "description" => "This column won't be added",
                "datatype" => "String",
              },
            ],
          },
        }
      end

      it "updates existing columns but preserves the datasource" do
        original_datasource = dataset.datasource
        original_column_count = dataset.columns.count

        updated_dataset = described_class.from_config(update_config,
                                                    action: :update,
                                                    target_dataset: dataset)

        # Dataset attributes are updated but name remains unchanged
        expect(updated_dataset.id).to eq(dataset.id)
        expect(updated_dataset.name).to eq(dataset.name)  # Original name preserved
        expect(updated_dataset.description).to eq("Updated description")

        # Datasource remains unchanged
        expect(updated_dataset.datasource).to eq(original_datasource)

        # Existing columns are updated
        passenger_id = updated_dataset.columns.find_by(name: "PassengerId")
        expect(passenger_id.description).to eq("Modified Passenger ID")
        expect(passenger_id.is_target).to be true
        expect(passenger_id.drop_if_null).to be true

        # New columns are not added
        expect(updated_dataset.columns.count).to eq(original_column_count)
        expect(updated_dataset.columns.find_by(name: "NewColumn")).to be_nil

        # Original columns are preserved
        expect(updated_dataset.columns.pluck(:name)).to match_array(dataset.columns.pluck(:name))
      end

      it "raises an error if action is update but no target_dataset specified" do
        expect {
          described_class.from_config(update_config, action: :update)
        }.to raise_error(ArgumentError, /Target dataset must be specified/)
      end

      it "raises an error if trying to update non-existent columns" do
        bad_config = {
          "dataset" => {
            "name" => "Any Name",
            "columns" => [
              {
                "name" => "NonExistentColumn",
                "description" => "This column doesn't exist",
                "datatype" => "String",
              },
            ],
          },
        }

        expect {
          described_class.from_config(bad_config, action: :update, target_dataset: dataset)
        }.to raise_error(EasyML::InvalidConfigurationError, /Column 'NonExistentColumn' not found/)
      end
    end
  end
end
