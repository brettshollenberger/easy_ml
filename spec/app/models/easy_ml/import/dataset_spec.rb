require "spec_helper"
require "support/model_spec_helper"

RSpec.describe EasyML::Import::Dataset do
  include ModelSpecHelper

  let(:dataset) { titanic_dataset }
  let(:config) do
    dataset.update(name: "Different Dataset Name", description: "The titanic dataset")
    dataset.columns.find_by(name: "PassengerId").update(description: "Updated Passenger ID", drop_if_null: true)
    dataset.columns.find_by(name: "Survived").update(is_target: true)

    dataset.to_config
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
        expect(new_dataset.datasource.name).to eq("Titanic Extended")
        expect(new_dataset.datasource.datasource_type).to eq("file")
        expect(new_dataset.datasource.root_dir).to eq dataset.datasource.root_dir

        # Verifies all columns are created
        expect(new_dataset.columns.count).to eq(12)
        passenger_id = new_dataset.columns.find_by(name: "PassengerId")
        expect(passenger_id.description).to eq("Updated Passenger ID")
        expect(passenger_id.drop_if_null).to be true

        survived = new_dataset.columns.find_by(name: "Survived")
        expect(survived).to be_present
        expect(survived.datatype).to eq("integer")
        expect(survived.is_target).to be true
      end
    end

    context "when updating an existing dataset" do
      let(:update_config) do
        dataset.to_config.deep_merge!(
          dataset: {
            name: "Completely Different Name",  # Name in config doesn't matter
            description: "Updated description",
            columns: [
              {
                name: "PassengerId",
                description: "Modified Passenger ID",
                drop_if_null: true,
                is_target: true,
              },
              {
                name: "NewColumn",
              },
            ],
          },
        )
      end

      it "updates existing columns but preserves the datasource" do
        original_datasource = dataset.datasource
        original_column_count = dataset.columns.count

        updated_dataset = described_class.from_config(update_config,
                                                      action: :update,
                                                      dataset: dataset)

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
        expect(updated_dataset.columns.count).to eq(12)
        expect(updated_dataset.columns.pluck(:name)).to match_array(dataset.columns.pluck(:name))
      end

      it "calls refresh_async when config changes require refresh" do
        # Update a column's drop_if_null setting which requires refresh
        update_config = dataset.to_config.deep_merge!(
          dataset: {
            columns: [
              {
                name: "PassengerId",
                drop_if_null: true,  # This change requires refresh
              },
            ],
          },
        )

        expect_any_instance_of(EasyML::Dataset).to receive(:refresh_async)

        described_class.from_config(update_config,
                                    action: :update,
                                    dataset: dataset)
      end

      it "raises an error if action is update but no dataset specified" do
        expect {
          described_class.from_config(update_config, action: :update)
        }.to raise_error(ArgumentError, /Target dataset must be specified/)
      end
    end
  end
end
