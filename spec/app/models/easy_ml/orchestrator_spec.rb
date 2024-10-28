require "spec_helper"
require "support/model_spec_helper"

RSpec.describe EasyML::Orchestrator do
  include ModelSpecHelper
  let(:root_dir) do
    Rails.root
  end

  let(:datasource) do
    EasyML::Datasource.create(
      name: "Polars Datasource",
      datasource_type: :polars,
      df: df
    )
  end

  let(:dataset) do
    dataset_config[:datasource] = datasource
    EasyML::Dataset.create(
      name: "Dataset",
      **dataset_config
    )
  end

  let(:model) do
    model_config[:name] = "My Model"
    EasyML::Model.create(**model_config)
  end

  describe ".predict" do
    it "loads model and makes predictions", :focus do
      model.model_file = model_file
      model.save
      model.promote
      df, = model.dataset.test(split_ys: true)
      model_preds = model.predict(df)

      orch_preds = described_class.predict(model.name, df)
      expect(orch_preds).to eq model_preds
      expect(model_preds.length).to eq(df.length)
    end

    it "reuses the same model instance across predictions" do
      model # ensure model is created

      first_model = nil
      second_model = nil

      # Capture the model instance used in first prediction
      allow_any_instance_of(EasyML::Model).to receive(:predict) do |instance, df|
        first_model = instance
        Array.new(df.height) { rand }
      end

      described_class.predict("test_model", dataframe)

      # Capture the model instance used in second prediction
      allow_any_instance_of(EasyML::Model).to receive(:predict) do |instance, df|
        second_model = instance
        Array.new(df.height) { rand }
      end

      described_class.predict("test_model", dataframe)

      expect(first_model).to eq(second_model)
    end

    it "handles concurrent predictions safely" do
      model # ensure model is created

      threads = []
      results = []
      mutex = Mutex.new

      10.times do
        threads << Thread.new do
          result = described_class.predict("test_model", dataframe)
          mutex.synchronize { results << result }
        end
      end

      threads.each(&:join)

      expect(results.length).to eq(10)
      results.each do |result|
        expect(result).to be_an(Array)
        expect(result.length).to eq(3)
      end
    end

    it "raises error for non-existent model" do
      expect do
        described_class.predict("non_existent_model", dataframe)
      end.to raise_error(ActiveRecord::RecordNotFound)
    end

    it "loads new model version when model is updated" do
      original_model = model

      # First prediction
      described_class.predict("test_model", dataframe)

      # Create new version of model
      new_model = create(:easy_ml_model,
                         name: "test_model",
                         status: :inference,
                         model_type: "xgboost")

      # Update original model to non-inference status
      original_model.update!(status: :archived)

      # Track which model instance is used
      used_model = nil
      allow_any_instance_of(EasyML::Model).to receive(:predict) do |instance, df|
        used_model = instance
        Array.new(df.height) { rand }
      end

      # Second prediction should use new model
      described_class.predict("test_model", dataframe)

      expect(used_model.id).to eq(new_model.id)
    end
  end
end
