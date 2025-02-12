require "spec_helper"
require "support/model_spec_helper"

RSpec.describe EasyML::Import::Model do
  include ModelSpecHelper

  let(:dataset) { titanic_dataset }
  let(:model) { titanic_model }

  before(:each) do
    EasyML::Cleaner.clean
    dataset.refresh
    model
  end

  describe ".from_config" do
    it "imports a model with its dataset configuration" do
      config = EasyML::Export::Model.to_config(model)
      model.destroy!
      dataset.destroy!

      imported_model = described_class.from_config(config)

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
      config = EasyML::Export::Model.to_config(model)
      config["model"]["configuration"]["hyperparameters"]["max_depth"] = 8
      config["model"]["dataset"]["columns"].detect { |c| c["name"] == "Age" }["description"] = "Updated description"

      updated_model = described_class.from_config(config)

      expect(updated_model.id).to eq(model.id)
      expect(updated_model.configuration["hyperparameters"]["max_depth"]).to eq(8)
      expect(updated_model.dataset.columns.find_by(name: "Age").description).to eq("Updated description")
    end
  end
end
