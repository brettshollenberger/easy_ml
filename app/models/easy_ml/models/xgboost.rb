module EasyML
  module Models
    class XGBoost < EasyML::Model
      include GlueGun::DSL

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

        @booster.predict(preprocess(xs))
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
        xs = xs.to_a.map(&:values)
        ys = ys.to_a.map(&:values)
        dtrain = d_matrix_class.new(xs, label: ys)
        @model = base_model.train(hyperparameters.to_h, dtrain)
      end

      def train_in_batches
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
              value.hash.to_f # Convert String to a float (using its hash)
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
    end
  end
end
