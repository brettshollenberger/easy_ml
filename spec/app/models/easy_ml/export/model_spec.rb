require "spec_helper"
require "support/model_spec_helper"

RSpec.describe "Model Export" do
  include ModelSpecHelper

  let(:dataset) { titanic_dataset }
  let(:model) { titanic_model }
  let(:config) do
    model.to_config
  end

  before(:each) do
    EasyML::Cleaner.clean
    dataset.refresh
    mock_s3_upload
    model.update(
      name: "Different Model Name",
      task: "classification",
      hyperparameters: {
        max_depth: 8,
        learning_rate: 0.1,
      },
    )

    model.save
    model.train(async: false)
    model.deploy(async: false)
  end

  describe "Model Export" do
    context "when exporting model only" do
      it "exports model configuration without dataset" do
        config = EasyML::Export::Model.to_config(model, include_dataset: false)

        expect(config).to be_a(HashWithIndifferentAccess)
        expect(config[:model]).to be_present
        expect(config[:model][:name]).to eq("Different Model Name")
        expect(config[:model][:model_type]).to eq("xgboost")
        expect(config[:model][:configuration][:task]).to eq("classification")
        expect(config[:model][:configuration][:hyperparameters][:max_depth]).to eq(8)
        expect(config[:model][:weights]).to be_present
        expect(config[:model][:dataset]).to be_nil
      end
    end

    context "when exporting model with dataset" do
      it "exports model configuration with dataset" do
        config = EasyML::Export::Model.to_config(model, include_dataset: true)

        expect(config).to be_a(HashWithIndifferentAccess)
        expect(config[:model]).to be_present
        expect(config[:model][:name]).to eq("Different Model Name")
        expect(config[:model][:model_type]).to eq("xgboost")
        expect(config[:model][:weights]).to be_present

        # Dataset config should be included
        dataset_config = config[:model][:dataset]
        expect(dataset_config).to be_present
        expect(dataset_config[:name]).to eq("Titanic")
        expect(dataset_config[:datasource][:name]).to eq("Titanic Extended")
      end
    end

    it "excludes unconfigurable columns" do
      config = EasyML::Export::Model.to_config(model)

      EasyML::Export::Model::UNCONFIGURABLE_COLUMNS.each do |column|
        expect(config[:model]).not_to have_key(column)
      end
    end
  end
end
