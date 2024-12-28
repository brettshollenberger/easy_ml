require "spec_helper"

RSpec.describe EasyML::Features do
  describe "Registry" do
    describe ".find" do
      it "finds feature by name and namespace" do
        feature = EasyML::Features::Registry.find("TestFeatureClass")&.features.first
        expect(feature[:name]).to eq("Test Feature")
      end

      it "returns nil for non-existent feature" do
        feature = EasyML::Features::Registry.find("non_existent")
        expect(feature).to be_nil
      end
    end

    describe ".list" do
      it "lists all features" do
        features = EasyML::Features::Registry.list_flat&.flat_map(&:features)
        expect(features.first[:name]).to eq("Bad Feature")
      end
    end
  end
end
