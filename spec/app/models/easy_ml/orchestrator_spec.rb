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
    it "loads model and makes predictions" do
      model.model_file = model_file
      model.version = model_file.filename.gsub(/\.json/, "")
      model.save
      model.promote

      df, = model.dataset.test(split_ys: true)
      model_preds = model.predict(df)

      orch_preds = described_class.predict(model.name, df)
      expect(orch_preds).to eq model_preds
      expect(model_preds.length).to eq(df.length)
    end

    it "doesn't reload the model when model already loaded" do
      expect_any_instance_of(EasyML::Core::Models::XGBoost).to receive(:load).once.and_call_original

      model.model_file = model_file
      model.version = model_file.filename.gsub(/\.json/, "")
      model.save
      model.promote
      df, = model.dataset.test(split_ys: true)

      3.times do
        described_class.predict(model.name, df)
      end
    end

    it "does reload the model when inference model changes" do
      model.model_file = model_file
      model.version = model_file.filename.gsub(/\.json/, "")
      model.save
      model.promote
      df, = model.dataset.test(split_ys: true)

      allow_any_instance_of(EasyML::ModelFile).to receive(:cleanup).and_return(true)

      3.times do
        described_class.predict(model.name, df)
      end

      model2 = model.fork
      expect(model2.promotable?).to be_falsey
      expect { model2.promote }.to raise_error "Cannot promote: Model has not been trained"
      model2.model_file = model_file
      model2.save
      expect(model2.promotable?).to eq true
      model2.promote

      expect_any_instance_of(EasyML::Core::Models::XGBoost).to receive(:load).once.and_call_original
      3.times do
        described_class.predict(model.name, df)
      end
    end

    it "raises error for non-existent model" do
      expect do
        described_class.predict("non_existent_model", model.dataset.test(split_ys: true).first)
      end.to raise_error(ActiveRecord::RecordNotFound)
    end
  end

  describe ".fork" do
  end
end
