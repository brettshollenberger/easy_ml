require "spec_helper"
require "support/model_spec_helper"

RSpec.describe "Model Import" do
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
    model
  end

  describe "Model Import" do
    context "when importing model only" do
      let(:model_only_config) do
        config.deep_merge!(
          model: {
            name: "Model Only Import",
            configuration: {
              hyperparameters: {
                max_depth: 10,
              },
            },
          },
        )
      end

      context "with action: :create" do
        it "raises an error if dataset is not specified" do
          expect {
            EasyML::Import::Model.from_config(model_only_config,
                                              action: :create,
                                              include_dataset: false)
          }.to raise_error(ArgumentError, /Dataset must be specified when creating a model/)
        end

        it "recreates the new model, including weights" do
          imported_model = EasyML::Import::Model.from_config(model_only_config,
                                                             action: :create,
                                                             include_dataset: false,
                                                             dataset: dataset)

          expect(imported_model.id).not_to eq(model.id)
          expect(imported_model.name).to eq("Model Only Import")
          expect(imported_model.configuration["hyperparameters"]["max_depth"]).to eq(10)
          expect(imported_model.configuration["hyperparameters"]["learning_rate"]).to eq(0.1)

          # Should use provided dataset
          expect(imported_model.dataset).to eq(dataset)

          expect(imported_model.weights).to match(hash_including(model_only_config.dig("model", "weights")))

          row = imported_model.dataset.data[0]
          expect(imported_model.dataset.normalize(row)).to eq(model.dataset.normalize(row))

          imported_evals = imported_model.evals.transform_values { |eval| eval.round(2) }
          orig_evals = model.evals.transform_values { |eval| eval.round(2) }
          expect(imported_evals).to match(hash_including(orig_evals))

          imported_model.deploy(async: false)

          pred_imported = EasyML::Predict.predict(imported_model.slug, row)
          pred_orig = EasyML::Predict.predict(model.slug, row)

          expect(pred_imported.prediction_value).to eq(pred_orig.prediction_value)
          expect(pred_imported.normalized_input).to match(hash_including(pred_orig.normalized_input))
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
            dataset: {
              name: "Updated Dataset Name",
              description: "Updated dataset description",
              columns: config.dig("model", "dataset", "columns").map do |col|
                if col["name"] == "Age"
                  col.merge!(
                    description: "Updated Age description",
                    drop_if_null: true,
                  )
                else
                  col
                end
              end,
            },
          },
        )
      end

      context "with action: :create" do
        it "creates new model and dataset, avoiding slug conflict" do
          imported_model = EasyML::Import::Model.from_config(model_with_dataset_config.deep_dup,
                                                             action: :create,
                                                             include_dataset: true)

          expect(imported_model.id).not_to eq(model.id)
          expect(imported_model.name).to eq("Different Model Name (Revision 2)")
          expect(imported_model.slug).not_to eq(model.slug)

          # Should create new dataset
          expect(imported_model.dataset.id).not_to eq(dataset.id)
          expect(imported_model.dataset.name).to eq("Updated Dataset Name")
          expect(imported_model.dataset.description).to eq("Updated dataset description")

          age_column = imported_model.dataset.columns.find_by(name: "Age")
          expect(age_column.description).to eq("Updated Age description")
          expect(age_column.drop_if_null).to be true

          imported_model2 = EasyML::Import::Model.from_config(model_with_dataset_config.deep_dup,
                                                              action: :create,
                                                              include_dataset: true)
          expect(imported_model2.name).to eq "Different Model Name (Revision 3)"
          expect(imported_model2.slug).to eq "different_model_name_revision_3"
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
