require "spec_helper"
require "support/model_spec_helper"

RSpec.describe "Dataset Export" do
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

  let(:feature) do
    dataset.features.create!(
      name: "FamilySize",
      feature_class: "FamilySizeFeature",
    )
  end

  before(:each) do
    EasyML::Cleaner.clean
    feature
    dataset.refresh
  end

  describe "Dataset Export" do
    it "exports dataset configuration with all components" do
      config = EasyML::Export::Dataset.to_config(dataset)

      expect(config).to be_a(HashWithIndifferentAccess)
      expect(config[:dataset]).to be_present
      expect(config[:dataset][:name]).to eq(dataset.name)
      expect(config[:dataset][:datasource]).to be_present
      expect(config[:dataset][:columns]).to be_present
      expect(config[:dataset][:features]).to be_present
    end

    it "excludes unconfigurable columns" do
      config = EasyML::Export::Dataset.to_config(dataset)

      EasyML::Export::Dataset::UNCONFIGURABLE_COLUMNS.each do |column|
        expect(config[:dataset]).not_to have_key(column)
      end
    end
  end
end
