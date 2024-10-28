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
      orig_path = model.model_file.full_path
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
      model2.fit
      model2.save
      expect(model2.promotable?).to eq true
      model2.promote

      expect_any_instance_of(EasyML::Core::Models::XGBoost).to receive(:load).once.and_call_original
      3.times do
        described_class.predict(model.name, df)
      end
      allow_any_instance_of(EasyML::ModelFile).to receive(:cleanup).and_call_original
      model2.model_file.cleanup([orig_path]) # Keep only the original file
      expect(Dir.glob(File.join(Pathname.new(orig_path).dirname, "**/*.json")).count).to eq 1
    end

    it "raises error for non-existent model" do
      expect do
        described_class.predict("non_existent_model", model.dataset.test(split_ys: true).first)
      end.to raise_error(ActiveRecord::RecordNotFound)
    end
  end

  describe ".fork" do
    it "returns existing training model if one exists" do
      # Create and promote first model
      model.model_file = model_file
      model.version = model_file.filename.gsub(/\.json/, "")
      model.save
      model.promote

      # Create a training model
      training_model = model.fork
      expect(training_model.status).to eq "training"

      # Fork should return existing training model
      forked = described_class.fork(model.name)
      expect(forked).to eq training_model
      model.model_file.cleanup([model.model_file.full_path]) # Keep only the original file
    end

    it "forks inference model if no training model exists" do
      Timecop.freeze(EST.now)
      model.model_file = model_file
      model.version = model_file.filename.gsub(/\.json/, "")
      model.save
      model.promote

      Timecop.freeze(EST.now + 3.minutes)
      forked = described_class.fork(model.name)
      expect(forked.status).to eq "training"
      expect(forked.name).to eq model.name
      expect(forked.version).not_to eq model.version

      Timecop.return
      model.model_file.cleanup([model.model_file.full_path]) # Keep only the original file
    end

    it "raises error for non-existent model" do
      expect do
        described_class.fork("non_existent_model")
      end.to raise_error(ActiveRecord::RecordNotFound)
    end
  end
end
