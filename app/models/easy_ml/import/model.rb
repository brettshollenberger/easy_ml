module EasyML
  module Import
    class Model
      def self.permitted_keys
        @permitted_keys ||= EasyML::Model.columns.map(&:name).map(&:to_sym) -
                            EasyML::Export::Model::UNCONFIGURABLE_COLUMNS.map(&:to_sym) +
                            [:weights] +
                            EasyML::Model.configuration_attributes.map(&:to_sym) +
                            [:dataset, :splitter, :retraining_job]
      end

      def self.from_config(json_config, action: nil, model: nil, include_dataset: true, dataset: nil)
        raise ArgumentError, "Action must be specified" unless action.present?
        raise ArgumentError, "Target model must be specified" if action == :update && model.nil?
        raise ArgumentError, "Dataset must be specified when creating a model" if action == :create && !include_dataset && dataset.nil?

        config = json_config.is_a?(String) ? JSON.parse(json_config) : json_config
        config = config.deep_dup.with_indifferent_access

        # Validate the configuration
        validate(config)
        model_config = config["model"]

        # Config variables would skip custom setters, so better to manually merge
        configuration = model_config.delete("configuration")
        model_config.merge!(configuration) if configuration.present?

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
        model = EasyML::Model.new(model_config.except("weights", "dataset", "retraining_job"))
        model.dataset = model_dataset

        model_name = model_config["name"]
        if (existing_model = EasyML::Model.find_by(name: model_name)).present?
          model.name = generate_unique_name(model_name)
        end
        model.save!

        retraining_job = EasyML::RetrainingJob.from_config(model_config["retraining_job"], model) if model_config["retraining_job"].present?

        # Update weights if present
        if model_config["weights"].present?
          model.update!(weights: model_config["weights"])
          model.import
        end

        model
      end

      def self.update_model(model, model_config, include_dataset:)
        # Update dataset if included
        if include_dataset && model_config["dataset"].present?
          dataset_config = { "dataset" => model_config.delete("dataset") }
          EasyML::Import::Dataset.from_config(dataset_config, action: :update, dataset: model.dataset)
        end

        # Update model attributes except name (preserve original name)
        model.update!(model_config.except("name", "weights", "dataset", "retraining_job"))

        # Update weights if present
        if model_config["weights"].present?
          model.update!(weights: model_config["weights"])
          model.import
        end

        model
      end

      def self.validate(json_config)
        config = json_config.is_a?(String) ? JSON.parse(json_config) : json_config
        config = config.deep_dup.with_indifferent_access

        # Validate root keys: must have only "model"
        extra_keys = config.keys.map(&:to_sym) - [:model]
        raise ArgumentError, "Invalid root keys: #{extra_keys.join(", ")}" unless extra_keys.empty?

        model_config = config[:model]
        # Validate that model_config does not contain keys that are unconfigurable
        extra_keys = model_config.keys.map(&:to_sym) - permitted_keys
        raise ArgumentError, "Invalid model keys: #{extra_keys.join(", ")}" unless extra_keys.empty?

        # Delegate nested validations to individual importers
        if model_config["dataset"].present?
          model_config["dataset"] = EasyML::Import::Dataset.validate(model_config["dataset"])
        end

        if model_config["retraining_job"].present?
          model_config["retraining_job"] = EasyML::Import::RetrainingJob.validate(model_config["retraining_job"])
        end

        config
      end

      def self.generate_unique_name(base_name)
        revision = EasyML::Model.where("name LIKE ?", "#{base_name} (Revision %)")
          .map { |m| m.name.match(/\(Revision (\d+)\)/).try(:[], 1).try(:to_i) }
          .compact
          .max || 0

        "#{base_name} (Revision #{revision + 1})"
      end
    end
  end
end
