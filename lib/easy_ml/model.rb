module EasyML
  class Model
    include GlueGun::DSL
    include EasyML::Logging

    attribute :verbose, :boolean, default: false
    attribute :root_dir, :string
    attribute :task, :string, default: :regression
    validates :task, inclusion: { in: %w[regression classification] }
    attribute :version, :string

    def initialize(options = {})
      super(options.reverse_merge!(version: generate_version_string))
    end

    attribute :metrics, required: true
    validate :validate_metrics_for_task
    def validate_metrics_for_task
      case task.to_sym
      when :regression
        %w[mean_absolute_error mean_squared_error root_mean_squared_error r2_score]
      when :classification
        %w[accuracy_score precision_score recall_score f1_score auc roc_auc]
      else
        []
      end
    end

    attribute :root_dir
    def root_dir=(value)
      super(Pathname.new(value).append("models"))
    end

    def model_path
      File.join(root_dir, "#{version}.bin")
    end

    def fit(xs, ys)
      raise NotImplementedError, "Subclasses must implement fit method"
    end

    def predict(xs)
      raise NotImplementedError, "Subclasses must implement predict method"
    end

    def save(path = nil)
      raise NotImplementedError, "Subclasses must implement save method"
    end

    def load
      raise NotImplementedError, "Subclasses must implement load method"
    end

    def get_params
      hyperparameters.to_h
    end

    private

    def generate_version_string
      timestamp = Time.now.utc.strftime("%Y%m%d%H%M%S")
      model_name = self.class.name.split("::").last.underscore
      "#{model_name}_#{timestamp}"
    end
  end
end
