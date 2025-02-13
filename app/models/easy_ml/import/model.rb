module EasyML
  module Import
    class Model
      def self.from_config(json_config, action: nil, model: nil, include_dataset: true, dataset: nil)
        raise ArgumentError, "Action must be specified" unless action.present?
        raise ArgumentError, "Target model must be specified" if action == :update && model.nil?
        raise ArgumentError, "Dataset must be specified when creating a model" if action == :create && !include_dataset && dataset.nil?

        config = json_config.is_a?(String) ? JSON.parse(json_config) : json_config
        config = config.deep_dup.with_indifferent_access
        model_config = config["model"]

        # Config variables would skip custom setters, so better to manually merge
        configuration = model_config.delete("configuration")
        model_config.merge!(configuration)

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

        model_name = model_config["name"]
        if (existing_model = EasyML::Model.find_by(name: model_name)).present?
          model.name = generate_unique_name(model_name)
        end
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

        # Handle model name
        model_name = model_config["name"]
        if model_name != model.name && (existing_model = EasyML::Model.find_by(name: model_name)).present?
          model_config["name"] = generate_unique_name(model_name)
        end

        # Update model
        model.update!(model_config.except("weights", "dataset"))
        model.update!(weights: model_config["weights"]) if model_config["weights"].present?
        model.import

        model
      end

      def self.generate_unique_name(base_name)
        max_model_name = EasyML::Model.where("name LIKE '%(Revision %'").maximum(:name)
        if max_model_name.nil?
          "#{base_name} (Revision 2)"
        else
          revision = max_model_name.split(" ").last.to_i
          "#{base_name} (Revision #{revision + 1})"
        end
      end
    end
  end
end
