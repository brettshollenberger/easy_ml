# == Schema Information
#
# Table name: easy_ml_models
#
#  id            :bigint           not null, primary key
#  name          :string           not null
#  model_type    :string
#  status        :string
#  dataset_id    :bigint
#  configuration :json
#  version       :string           not null
#  root_dir      :string
#  file          :json
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#
module EasyML
  module Models
    class XGBoost < BaseModel
      Hyperparameters = EasyML::Models::Hyperparameters::XGBoost

      OBJECTIVES = {
        classification: {
          binary: %w[binary:logistic binary:hinge],
          multiclass: %w[multi:softmax multi:softprob]
        },
        regression: %w[reg:squarederror reg:logistic]
      }

      add_configuration_attributes :early_stopping_rounds
      attr_accessor :xgboost_model, :booster

      def build_hyperparameters(params)
        params = {} if params.nil?
        return nil unless params.is_a?(Hash)

        params.to_h.symbolize_keys!

        params[:booster] = :gbtree unless params.key?(:booster)

        klass = case params[:booster].to_sym
                when :gbtree
                  Hyperparameters::GBTree
                when :dart
                  Hyperparameters::Dart
                when :gblinear
                  Hyperparameters::GBLinear
                else
                  raise "Unknown booster type: #{booster}"
                end
        raise "Unknown booster type #{booster}" unless klass.present?

        klass.new(params)
      end

      def callbacks=(params)
        return [] unless params.is_a?(Array)

        params.map do |conf|
          callback_type = conf.keys.first.to_sym
          conf.values.first.symbolize_keys!

          klass = case callback_type
                  when :wandb then Wandb::XGBoostCallback
                  end
          raise "Unknown callback type #{callback_type}" unless klass.present?
        end

        super(params)
      end

      def callbacks
        return @_callbacks if @_callbacks

        raw_params = model.instance_variable_get(:@callbacks)

        return [] if raw_params.nil? || !raw_params.is_a?(Array)

        @_callbacks = raw_params.map do |conf|
          callback_type = conf.keys.first.to_sym
          callback_config = conf.values.first.symbolize_keys!

          klass = case callback_type
                  when :wandb then Wandb::XGBoostCallback
                  end
          raise "Unknown callback type #{callback_type}" unless klass.present?

          klass.new(**callback_config)
        end
      end

      def is_fit?
        @booster.present? && @booster.feature_names.any?
      end

      def fit(x_train: nil, y_train: nil, x_valid: nil, y_valid: nil)
        validate_objective

        d_train, d_valid, = prepare_data if x_train.nil?
        evals = [[d_train, "train"], [d_valid, "eval"]]
        @booster = base_model.train(hyperparameters.to_h, d_train,
                                    evals: evals,
                                    num_boost_round: hyperparameters["n_estimators"],
                                    callbacks: callbacks || [],
                                    early_stopping_rounds: hyperparameters.to_h.dig("early_stopping_rounds"))
      end

      def predict(xs)
        raise "No trained model! Train a model before calling predict" unless @booster.present?
        raise "Cannot predict on nil — XGBoost" if xs.nil?

        begin
          y_pred = @booster.predict(preprocess(xs))
        rescue StandardError => e
          raise e unless e.message.match?(/Number of columns does not match/)

          raise %(
              >>>>><<<<<
              XGBoost received predict with unexpected features!
              >>>>><<<<<

              Model expects features:
              #{feature_names}
              Model received features:
              #{xs.columns}
            )
        end

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

      def unload
        @booster = nil
      end

      def loaded?
        @booster.present? && @booster.feature_names.any?
      end

      def load_model_file(path)
        return if loaded?

        initialize_model do
          attrs = {
            params: hyperparameters.to_h.symbolize_keys,
            model_file: path
          }.deep_compact
          booster_class.new(**attrs)
        end
      end

      def model_changed?(prev_hash)
        return false unless @booster.present? && @booster.feature_names.any?

        current_model_hash = nil
        Tempfile.create(["xgboost_model", ".json"]) do |tempfile|
          @booster.save_model(tempfile.path)
          tempfile.rewind
          JSON.parse(tempfile.read)
          current_model_hash = Digest::SHA256.file(tempfile.path).hexdigest
        end
        current_model_hash != prev_hash
      end

      def save_model_file(path)
        puts "Saving model file!"
        path = path.to_s
        ensure_directory_exists(File.dirname(path))
        extension = Pathname.new(path).extname.gsub("\.", "")
        path = "#{path}.json" unless extension == "json"

        @booster.save_model(path)
        path
      end

      def feature_names
        @booster.feature_names
      end

      def feature_importances
        score = @booster.score(importance_type: @importance_type || "gain")
        scores = @booster.feature_names.map { |k| score[k] || 0.0 }
        total = scores.sum.to_f
        fi = scores.map { |s| s / total }
        @booster.feature_names.zip(fi).to_h
      end

      def base_model
        ::XGBoost
      end

      def prepare_data
        if @d_train.nil?
          x_train, y_train = dataset.train(split_ys: true)
          x_valid, y_valid = dataset.valid(split_ys: true)
          x_test, y_test = dataset.test(split_ys: true)
          @d_train = preprocess(x_train, y_train)
          @d_valid = preprocess(x_valid, y_valid)
          @d_test = preprocess(x_test, y_test)
        end

        [@d_train, @d_valid, @d_test]
      end

      def preprocess(xs, ys = nil)
        orig_xs = xs.dup
        column_names = xs.columns
        xs = _preprocess(xs)
        ys = ys.nil? ? nil : _preprocess(ys).flatten
        kwargs = { label: ys }.compact
        begin
          ::XGBoost::DMatrix.new(xs, **kwargs).tap do |dmat|
            dmat.feature_names = column_names
          end
        rescue StandardError => e
          raise %(
            Error building data for XGBoost. Consider preprocessing your
            features. The error is:
            >>>>><<<<<
            #{e.message}
            >>>>><<<<<
            A sample of your dataset:
            #{orig_xs[0..5]}
            Which was normalized to:
            #{xs[0..5]}

            #{if ys.present?
                %(
                This may also be due to your targets:
                #{ys[0..5]}
              )
              else
                ""
              end}
          )
        end
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

      def train_in_batches
        validate_objective

        # Initialize the model with the first batch
        @xgboost_model = nil
        @booster = nil
        x_valid, y_valid = dataset.valid(split_ys: true)
        d_valid = preprocess(x_valid, y_valid)

        num_iterations = hyperparameters.to_h["n_estimators"]
        current_iteration = 0
        num_batches = dataset.num_batches(:train)
        iterations_per_batch = num_iterations / num_batches
        stopping_points = (1..num_batches).to_a.map { |n| n * iterations_per_batch }
        stopping_points[-1] = num_iterations
        current_batch = 0

        callbacks = self.callbacks.nil? ? [] : self.callbacks.dup
        callbacks << ::XGBoost::EvaluationMonitor.new(period: 1)
        cb_container = ::XGBoost::CallbackContainer.new(callbacks)

        dataset.train(split_ys: true) do |x_train, y_train|
          d_train = preprocess(x_train, y_train)

          evals = [[d_train, "train"], [d_valid, "eval"]]

          until current_iteration == stopping_points[current_batch]
            fit_batch(d_train, current_iteration, evals, cb_container)
            current_iteration += 1
          end
          current_batch += 1
        end

        @booster = cb_container.after_training(@booster)
      end

      def fit_batch(d_train, current_iteration, evals, cb_container)
        if @booster.nil?
          @booster = booster_class.new(params: @hyperparameters.to_h, cache: [d_train] + evals.map do |d|
            d[0]
          end, early_stopping_rounds: @hyperparameters.to_h.dig(:early_stopping_rounds))
        end

        @booster = cb_container.before_training(@booster)
        cb_container.before_iteration(@booster, current_iteration, d_train, evals)
        @booster.update(d_train, current_iteration)
        cb_container.after_iteration(@booster, current_iteration, d_train, evals)
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

      def initialize_model
        @xgboost_model = model_class.new(n_estimators: @hyperparameters.to_h.dig(:n_estimators))
        @booster = yield
        @xgboost_model.instance_variable_set(:@booster, @booster)
      end

      def validate_objective
        objective = hyperparameters.objective
        unless task.present?
          raise ArgumentError,
                "cannot train model without task. Please specify either regression or classification (model.task = :regression)"
        end

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
