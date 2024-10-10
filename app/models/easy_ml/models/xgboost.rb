module EasyML
  module Models
    class XGBoost < EasyML::Model
      include GlueGun::DSL

      OBJECTIVES = {
        classification: {
          binary: %w[binary:logistic binary:hinge],
          multi_class: %w[multi:softmax multi:softprob]
        },
        regression: %w[reg:squarederror reg:logistic]
      }

      dependency :hyperparameters do |dep|
        dep.set_class EasyML::Models::Hyperparameters::XGBoost
        dep.bind_attribute :batch_size, default: 32
        dep.bind_attribute :learning_rate, default: 0.1
        dep.bind_attribute :max_depth, default: 6
        dep.bind_attribute :n_estimators, default: 100
        dep.bind_attribute :booster, default: "gbtree"
        dep.bind_attribute :objective, default: "reg:squarederror"
      end

      attr_accessor :model, :booster

      def predict(xs)
        raise "No trained model! Train a model before calling predict" unless @booster.present?
        raise "Cannot predict on nil — XGBoost" if xs.nil?

        y_pred = @booster.predict(preprocess(xs))

        case task.to_sym
        when :classification
          to_classification(y_pred)
        else
          y_pred
        end
      end

      def predict_proba(data)
        dmat = DMatrix.new(data)
        y_pred = @booster.predict(dmat)

        if y_pred.first.is_a?(Array)
          # multiple classes
          y_pred
        else
          y_pred.map { |v| [1 - v, v] }
        end
      end

      def load(path = nil)
        path ||= file
        path = path.file.file if path.class.ancestors.include?(CarrierWave::Uploader::Base)
        # retrieve_and_cache_file when is remote...
        raise "No existing model at #{path}" unless File.exist?(path)

        initialize_model do
          booster_class.new(params: hyperparameters.to_h, model_file: path)
        end
      end

      def _save_model_file(path)
        @booster.save_model(path)
      end

      def feature_importances
        @model.booster.feature_names.zip(@model.feature_importances).to_h
      end

      def base_model
        ::XGBoost
      end

      private

      def booster_class
        ::XGBoost::Booster
      end

      def d_matrix_class
        ::XGBoost::DMatrix
      end

      def model_class
        ::XGBoost::Model
      end

      def train
        validate_objective

        xs = xs.to_a.map(&:values)
        ys = ys.to_a.map(&:values)
        dtrain = d_matrix_class.new(xs, label: ys)
        @model = base_model.train(hyperparameters.to_h, dtrain)
      end

      def train_in_batches
        validate_objective

        # Initialize the model with the first batch
        @model = nil
        @booster = nil
        x_valid, y_valid = dataset.valid(split_ys: true)

        dataset.train(split_ys: true) do |x_train, y_train|
          puts x_train
          fit_batch(x_train, y_train, x_valid, y_valid)
        end
      end

      def _preprocess(df)
        df.to_a.map do |row|
          row.values.map do |value|
            case value
            when Time
              value.to_i # Convert Time to Unix timestamp
            when Date
              value.to_time.to_i # Convert Date to Unix timestamp
            when String
              value
            when TrueClass, FalseClass
              value ? 1.0 : 0.0 # Convert booleans to 1.0 and 0.0
            when Integer
              value
            else
              value.to_f # Ensure everything else is converted to a float
            end
          end
        end
      end

      def preprocess(xs, ys = nil)
        column_names = xs.columns
        xs = _preprocess(xs)
        ys = ys.nil? ? nil : _preprocess(ys).flatten
        kwargs = { label: ys }.compact
        ::XGBoost::DMatrix.new(xs, **kwargs).tap do |dmat|
          dmat.instance_variable_set(:@feature_names, column_names)
        end
      end

      def initialize_model
        @model = model_class.new(n_estimators: @hyperparameters.to_h.dig(:n_estimators))
        @booster = yield
        @model.instance_variable_set(:@booster, @booster)
      end

      def validate_objective
        objective = hyperparameters.objective
        case task.to_sym
        when :classification
          _, ys = dataset.data(split_ys: true)
          classification_type = ys[ys.columns.first].uniq.count <= 2 ? :binary : :multi_class
          allowed_objectives = OBJECTIVES[:classification][classification_type]
        else
          allowed_objectives = OBJECTIVES[task.to_sym]
        end
        return if allowed_objectives.map(&:to_sym).include?(objective.to_sym)

        raise ArgumentError,
              "cannot use #{objective} for #{task} task. Allowed objectives are: #{allowed_objectives.join(", ")}"
      end

      def fit_batch(x_train, y_train, x_valid, y_valid)
        d_train = preprocess(x_train, y_train)
        d_valid = preprocess(x_valid, y_valid)

        evals = [[d_train, "train"], [d_valid, "eval"]]

        # # If this is the first batch, create the booster
        if @booster.nil?
          initialize_model do
            base_model.train(@hyperparameters.to_h, d_train, evals: evals)
          end
        else
          # Update the existing booster with the new batch
          @model.update(d_train)
        end
      end

      def to_classification(y_pred)
        if y_pred.first.is_a?(Array)
          # multiple classes
          y_pred.map do |v|
            v.map.with_index.max_by { |v2, _| v2 }.last
          end
        else
          y_pred.map { |v| v > 0.5 ? 1 : 0 }
        end
      end
    end
  end
end
