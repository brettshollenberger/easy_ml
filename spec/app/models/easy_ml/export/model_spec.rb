require "spec_helper"
require "support/model_spec_helper"

RSpec.describe EasyML::Export::Model do
  include ModelSpecHelper

  let(:dataset) { titanic_dataset }
  let(:model) { titanic_model }

  before(:each) do
    EasyML::Cleaner.clean
    dataset.refresh
    model
  end

  describe ".to_config" do
    it "exports the model configuration with dataset" do
      mock_s3_upload

      model.save
      model.train(async: false)

      config = described_class.to_config(model)

      expect(config["model"]["name"]).to eq("Titanic")
      expect(config["model"]["model_type"]).to eq("xgboost")
      expect(config["model"]["configuration"]["task"]).to eq("classification")
      expect(config["model"]["configuration"]["hyperparameters"]["max_depth"]).to eq(6)
      expect(config["model"]["weights"]["learner"]).to be_a(Hash)

      # Dataset config should be included
      dataset_config = config["model"]["dataset"]
      expect(dataset_config["name"]).to eq("Titanic")
      expect(dataset_config["datasource"]["name"]).to eq("Titanic Extended")
    end

    it "excludes unconfigurable columns" do
      config = described_class.to_config(model)

      described_class::UNCONFIGURABLE_COLUMNS.each do |column|
        expect(config[:model]).not_to have_key(column)
      end
    end
  end
end
