require "spec_helper"

RSpec.describe EasyML::Transforms do
  before(:each) do
    EasyML::Transforms::Registry.clear
  end

  describe "Registry" do
    let(:test_transform_class) do
      Class.new do
        include EasyML::Transforms

        def uppercase_text(df)
          df # Mock implementation
        end
        transform :uppercase_text,
                  name: "text_to_upper",
                  description: "Converts text to uppercase"
      end
    end

    before do
      EasyML::Transforms::Registry.register(test_transform_class, namespace: :text)
    end

    describe ".register" do
      it "registers transforms with their metadata" do
        transforms = EasyML::Transforms::Registry.list(namespace: :text)
        expect(transforms["text_to_upper"]).to include(
          transform_class: test_transform_class,
          transform_method: :uppercase_text,
          description: "Converts text to uppercase"
        )
      end
    end

    describe ".find" do
      it "finds transform by name and namespace" do
        transform = EasyML::Transforms::Registry.find("text_to_upper", namespace: :text)
        expect(transform[:transform_method]).to eq(:uppercase_text)
      end

      it "returns nil for non-existent transform" do
        transform = EasyML::Transforms::Registry.find("non_existent", namespace: :text)
        expect(transform).to be_nil
      end
    end

    describe ".list" do
      it "lists all transforms in a namespace" do
        transforms = EasyML::Transforms::Registry.list(namespace: :text)
        expect(transforms.keys).to contain_exactly("text_to_upper")
      end

      it "lists all transforms when no namespace given" do
        transforms = EasyML::Transforms::Registry.list
        expect(transforms[:text].keys).to contain_exactly("text_to_upper")
      end
    end
  end
end
