require "spec_helper"
require "support/model_spec_helper"

RSpec.describe EasyML::Orchestrator do
  include ModelSpecHelper
  let(:datasource) do
    EasyML::Datasource.create(
      name: "Polars Datasource",
      datasource_type: "polars",
      df: df,
    )
  end

  before(:each) do
    EasyML::Cleaner.clean
    EasyML::Orchestrator.reset
  end

  after(:each) do
    EasyML::Cleaner.clean
    EasyML::Orchestrator.reset
  end

  let(:model) do
    pretrain_loans_model
  end

  describe ".predict" do
    it "loads model and makes predictions" do
      model.deploy

      df, = model.dataset.test(split_ys: true)
      model_preds = model.predict(df)

      orch_preds = described_class.predict(model.name, df)
      expect(orch_preds).to eq model_preds
      expect(model_preds.length).to eq(df.length)
    end

    it "doesn't reload the model when model already loaded" do
      model.deploy

      df, = model.dataset.test(split_ys: true)
      expect_any_instance_of(EasyML::Models::XGBoost).to receive(:initialize_model).once.and_call_original

      3.times do
        described_class.predict(model.name, df)
      end
    end

    it "does reload the model when inference model changes" do
      model.deploy
      df, = model.dataset.test(split_ys: true)

      # Orchestrator already ran model loading her
      3.times do
        described_class.predict(model.name, df)
      end

      randomize_hypers(model)
      model.fit
      expect(model).to be_deployable

      old_preds = model.latest_snapshot.predict(df)
      new_preds = model.predict(df)
      expect(old_preds).to_not eq new_preds

      model.deploy

      # So if Orchestrator runs model loading again here, test passes
      expect_any_instance_of(EasyML::Models::XGBoost).to receive(:initialize_model).once.and_call_original
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
end
