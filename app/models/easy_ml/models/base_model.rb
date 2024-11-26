module EasyML
  module Models
    class BaseModel
      include ActiveModel::Validations
      include EasyML::Concerns::Configurable
      include EasyML::Support::FileSupport

      attr_reader :model

      add_configuration_attributes :hyperparameters

      def initialize(model)
        @model = model
      end

      delegate :task, :dataset, :hyperparameters, to: :model

      # Required interface methods that subclasses must implement
      def predict(_xs)
        raise NotImplementedError, "#{self.class} must implement #predict"
      end

      def fit(_x_train = nil)
        raise NotImplementedError, "#{self.class} must implement #fit"
      end

      def model_changed?
        raise NotImplementedError, "#{self.class} must implement #model_changed?"
      end

      def feature_importances
        raise NotImplementedError, "#{self.class} must implement #feature_importances"
      end

      def save_model_file(path)
        raise NotImplementedError, "#{self.class} must implement #save_model_file"
      end

      def load_model_file(path)
        raise NotImplementedError, "#{self.class} must implement #load_model_file"
      end

      def loaded?
        raise NotImplementedError, "#{self.class} must implement #loaded?"
      end

      protected

      def validate_objective
        raise NotImplementedError, "#{self.class} must implement #validate_objective"
      end

      def validate_hyperparameters
        raise NotImplementedError, "#{self.class} must implement #validate_hyperparameters"
      end
    end
  end
end
