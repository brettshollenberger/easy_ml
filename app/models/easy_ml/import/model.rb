module EasyML
  module Import
    class Model
      def self.from_config(json_config, action: nil, model: nil, include_dataset: true, dataset: nil)
        raise ArgumentError, "Action must be specified" unless action.present?
        raise ArgumentError, "Target model must be specified" if action == :update && model.nil?
        raise ArgumentError, "Dataset must be specified when creating a model" if action == :create && !include_dataset && dataset.nil?

        config = json_config.is_a?(String) ? JSON.parse(json_config) : json_config
        model_config = config["model"]

        case action
        when :create
          create_model(model_config, include_dataset: include_dataset, dataset: dataset)
        when :update
          update_model(model, model_config, include_dataset: include_dataset)
        else
          raise ArgumentError, "Invalid action: #{action}. Must be :create or :update"
        end
      end

      private

      def self.create_model(model_config, include_dataset:, dataset:)
        # Handle dataset if included
        model_dataset = if include_dataset && model_config["dataset"].present?
            dataset_config = { "dataset" => model_config.delete("dataset") }
            EasyML::Import::Dataset.from_config(dataset_config, action: :create)
          else
            dataset
          end

        # Create model
        model = EasyML::Model.new(model_config.except("weights", "dataset"))
        model.dataset = model_dataset
        model.save!

        # Update weights if present
        model.update!(weights: model_config["weights"]) if model_config["weights"].present?
        model.import

        model
      end

      def self.update_model(model, model_config, include_dataset:)
        # Handle dataset if included
        if include_dataset && model_config["dataset"].present?
          dataset_config = { "dataset" => model_config.delete("dataset") }
          EasyML::Import::Dataset.from_config(dataset_config,
                                              action: :update,
                                              dataset: model.dataset)
        end

        # Update model
        model.update!(model_config.except("weights", "dataset"))
        model.update!(weights: model_config["weights"]) if model_config["weights"].present?

        model
      end
    end
  end
end
