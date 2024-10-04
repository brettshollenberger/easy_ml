module EasyML
  class Model
    include GlueGun::DSL
    include EasyML::Logging

    define_attr :verbose, default: false
    define_attr :task, required: true, default: :regression,
                       options: %w[regression classification]
    define_attr :metrics, required: true, options: lambda {
      case task.to_sym
      when :regression

      when :classification
      else
        []
      end
    }

    define_attr :root_dir do |root_dir|
      File.join(root_dir, "models")
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
