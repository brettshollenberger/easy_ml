module EasyML
  module Import
    class Model
      def self.from_config(json_config)
        config = json_config.is_a?(String) ? JSON.parse(json_config) : json_config
        model_config = config["model"]

        # Import dataset first
        dataset_config = { "dataset" => model_config.delete("dataset") }
        dataset = EasyML::Dataset.from_config(dataset_config)

        # Create or update model
        model = EasyML::Model.find_or_create_by(name: model_config["name"]) do |m|
          m.assign_attributes(model_config.except("weights"))
          m.dataset = dataset
        end
        model.update!(model_config.except("weights"))

        # Update weights if present
        model.update!(weights: model_config["weights"]) if model_config["weights"].present?

        model
      end
    end
  end
end
