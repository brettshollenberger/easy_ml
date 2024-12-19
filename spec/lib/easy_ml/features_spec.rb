require "spec_helper"

RSpec.describe EasyML::Features do
  before(:each) do
    EasyML::Features::Registry.clear
  end

  describe "Registry" do
    let(:test_feature_class) do
      Class.new do
        include EasyML::Features

        def uppercase_text(df)
          df # Mock implementation
        end

        feature :uppercase_text,
                name: "text_to_upper",
                description: "Converts text to uppercase"
      end
    end

    before do
      EasyML::Features::Registry.register(test_feature_class, namespace: :text)
    end

    describe ".register" do
      it "registers features with their metadata" do
        features = EasyML::Features::Registry.list(namespace: :text)
        expect(features["text_to_upper"]).to include(
          feature_class: test_feature_class,
          description: "Converts text to uppercase",
        )
      end
    end

    describe ".find" do
      it "finds feature by name and namespace" do
        feature = EasyML::Features::Registry.find("text_to_upper", namespace: :text)
        expect(feature[:name]).to eq(:uppercase_text)
      end

      it "returns nil for non-existent feature" do
        feature = EasyML::Features::Registry.find("non_existent", namespace: :text)
        expect(feature).to be_nil
      end
    end

    describe ".list" do
      it "lists all features in a namespace" do
        features = EasyML::Features::Registry.list(namespace: :text)
        expect(features.keys).to contain_exactly("text_to_upper")
      end

      it "lists all features when no namespace given" do
        features = EasyML::Features::Registry.list
        expect(features[:text].keys).to contain_exactly("text_to_upper")
      end
    end
  end
end
