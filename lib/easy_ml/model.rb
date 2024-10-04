module EasyML
  class Model
    include GlueGun::DSL
    include EasyML::Logging

    attribute :verbose, :boolean, default: false
    attribute :task, :array, default: :regression
    validates :task, inclusion: { in: %w[regression classification] }

    attribute :metrics, required: true
    validate :validate_metrics_for_task
    def validate_metrics_for_task
      binding.pry
      case task.to_sym
      when :regression

      when :classification
      else
        []
      end
    end

    attribute :root_dir
    def root_dir=(value)
      super(Pathname.new(value).append("models"))
    end

    def fit(xs, ys)
      raise NotImplementedError, "Subclasses must implement fit method"
    end

    def predict(xs)
      raise NotImplementedError, "Subclasses must implement predict method"
    end

    def save
      raise NotImplementedError, "Subclasses must implement save method"
    end

    def load
      raise NotImplementedError, "Subclasses must implement load method"
    end

    def get_params
      hyperparameters.to_h
    end

    private

    def model_path
      File.join(root_dir, "#{name}.model")
    end
  end
end
