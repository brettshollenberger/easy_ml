require "spec_helper"
require "support/model_spec_helper"

RSpec.describe "Model Import" do
  include ModelSpecHelper

  let(:dataset) { titanic_dataset }
  let(:model) { titanic_model }
  let(:config) do
    model.update(
      name: "Different Model Name",
      description: "XGBoost model for Titanic dataset",
      configuration: {
        task: "classification",
        hyperparameters: {
          max_depth: 8,
          learning_rate: 0.1,
        },
      },
    )

    model.train(async: false)
    model.to_config
  end

  before(:each) do
    EasyML::Cleaner.clean
    dataset.refresh
    model
  end

  describe "Model Import" do
    context "when importing model only" do
      let(:model_only_config) do
        config.deep_merge!(
          model: {
            name: "Model Only Import",
            description: "Updated description",
            configuration: {
              hyperparameters: {
                max_depth: 10,
              },
            },
          },
        )
      end

      context "with action: :create" do
        it "creates a new model without affecting dataset" do
          original_dataset = model.dataset
          model.destroy

          imported_model = EasyML::Import::Model.from_config(model_only_config,
                                                             action: :create,
                                                             include_dataset: false)

          expect(imported_model.id).not_to eq(model.id)
          expect(imported_model.name).to eq("Model Only Import")
          expect(imported_model.description).to eq("Updated description")
          expect(imported_model.configuration["hyperparameters"]["max_depth"]).to eq(10)
          expect(imported_model.configuration["hyperparameters"]["learning_rate"]).to eq(0.1)

          # Should use existing dataset
          expect(imported_model.dataset).to eq(original_dataset)
        end
      end

      context "with action: :update" do
        it "updates existing model without affecting dataset" do
          original_dataset_id = model.dataset_id
          original_dataset_name = model.dataset.name

          imported_model = EasyML::Import::Model.from_config(model_only_config,
                                                             action: :update,
                                                             model: model,
                                                             include_dataset: false)

          expect(imported_model.id).to eq(model.id)
          expect(imported_model.name).to eq("Model Only Import")
          expect(imported_model.description).to eq("Updated description")
          expect(imported_model.configuration["hyperparameters"]["max_depth"]).to eq(10)
          expect(imported_model.configuration["hyperparameters"]["learning_rate"]).to eq(0.1)

          # Dataset should remain unchanged
          expect(imported_model.dataset_id).to eq(original_dataset_id)
          expect(imported_model.dataset.name).to eq(original_dataset_name)
        end
      end
    end

    context "when importing model with dataset" do
      let(:model_with_dataset_config) do
        config.deep_merge!(
          model: {
            name: "Full Model Import",
            dataset: {
              name: "Updated Dataset Name",
              description: "Updated dataset description",
              columns: [
                {
                  name: "Age",
                  description: "Updated Age description",
                  drop_if_null: true,
                },
              ],
            },
          },
        )
      end

      context "with action: :create" do
        it "creates new model and dataset" do
          model.destroy
          dataset.destroy

          imported_model = EasyML::Import::Model.from_config(model_with_dataset_config,
                                                             action: :create,
                                                             include_dataset: true)

          expect(imported_model.id).not_to eq(model.id)
          expect(imported_model.name).to eq("Full Model Import")

          # Should create new dataset
          expect(imported_model.dataset.id).not_to eq(dataset.id)
          expect(imported_model.dataset.name).to eq("Updated Dataset Name")
          expect(imported_model.dataset.description).to eq("Updated dataset description")

          age_column = imported_model.dataset.columns.find_by(name: "Age")
          expect(age_column.description).to eq("Updated Age description")
          expect(age_column.drop_if_null).to be true
        end
      end

      context "with action: :update" do
        it "updates existing model and dataset" do
          imported_model = EasyML::Import::Model.from_config(model_with_dataset_config,
                                                             action: :update,
                                                             model: model,
                                                             include_dataset: true)

          expect(imported_model.id).to eq(model.id)
          expect(imported_model.name).to eq("Full Model Import")

          # Should update existing dataset
          expect(imported_model.dataset.id).to eq(dataset.id)
          expect(imported_model.dataset.name).to eq("Updated Dataset Name")
          expect(imported_model.dataset.description).to eq("Updated dataset description")

          age_column = imported_model.dataset.columns.find_by(name: "Age")
          expect(age_column.description).to eq("Updated Age description")
          expect(age_column.drop_if_null).to be true
        end
      end
    end

    it "raises an error if action is not specified" do
      expect {
        EasyML::Import::Model.from_config(config)
      }.to raise_error(ArgumentError, /Action must be specified/)
    end

    it "raises an error if action is update but no model specified" do
      expect {
        EasyML::Import::Model.from_config(config, action: :update)
      }.to raise_error(ArgumentError, /Target model must be specified/)
    end
  end
end
