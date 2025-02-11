require "spec_helper"
require "support/model_spec_helper"
require "support/file_spec_helper"

RSpec.describe EasyML::Model do
  include ModelSpecHelper

  let(:dataset) { titanic_dataset }
  let(:model) do
    titanic_model
  end

  before(:each) do
    EasyML::Cleaner.clean
    dataset.refresh
    model
  end

  describe "#to_config" do
    it "exports the model configuration with dataset" do
      mock_s3_upload

      model.save
      model.train(async: false)

      config = model.to_config

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
  end

  describe ".from_config" do
    it "imports a model with its dataset configuration" do
      config = model.to_config
      model.destroy!
      dataset.destroy!

      imported_model = EasyML::Model.from_config(config)

      expect(imported_model).to be_persisted
      expect(imported_model.name).to eq("Titanic")
      expect(imported_model.model_type).to eq("xgboost")
      expect(imported_model.configuration["task"]).to eq("classification")
      expect(imported_model.configuration["hyperparameters"]["max_depth"]).to eq(6)

      # Dataset should be created
      expect(imported_model.dataset).to be_present
      expect(imported_model.dataset.name).to eq("Titanic")
      expect(imported_model.dataset.datasource.name).to eq("Titanic Extended")
    end

    it "updates an existing model and dataset" do
      config = model.to_config
      config["model"]["configuration"]["hyperparameters"]["max_depth"] = 8
      config["model"]["dataset"]["columns"].detect { |c| c["name"] == "Age" }["description"] = "Updated description"

      updated_model = EasyML::Model.from_config(config)

      expect(updated_model.id).to eq(model.id)
      expect(updated_model.configuration["hyperparameters"]["max_depth"]).to eq(8)
      expect(updated_model.dataset.columns.find_by(name: "Age").description).to eq("Updated description")
    end
  end
end
