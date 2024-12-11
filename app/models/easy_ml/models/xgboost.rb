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
          multiclass: %w[multi:softmax multi:softprob],
        },
        regression: %w[reg:squarederror reg:logistic],
      }

      OBJECTIVES_FRONTEND = {
        classification: [
          { value: "binary:logistic", label: "Binary Logistic", description: "For binary classification" },
          { value: "binary:hinge", label: "Binary Hinge", description: "For binary classification with hinge loss" },
          { value: "multi:softmax", label: "Multiclass Softmax", description: "For multiclass classification" },
          { value: "multi:softprob", label: "Multiclass Probability",
            description: "For multiclass classification with probability output" },
        ],
        regression: [
          { value: "reg:squarederror", label: "Squared Error", description: "For regression with squared loss" },
          { value: "reg:logistic", label: "Logistic", description: "For regression with logistic loss" },
        ],
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

        overrides = {
          objective: model.objective,
        }
        params.merge!(overrides)

        klass.new(params)
      end

      def add_auto_configurable_callbacks(params)
        if EasyML::Configuration.wandb_api_key.present?
          params << {
            callback_type: :wandb,
            project_name: model.name,
          }
        end
      end

      def build_callbacks(params)
        return [] unless params.is_a?(Array)

        add_auto_configurable_callbacks(params)

        params.map do |conf|
          conf.symbolize_keys!
          if conf.key?(:callback_type)
            callback_type = conf[:callback_type]
          else
            callback_type = conf.keys.first.to_sym
            conf = conf.values.first.symbolize_keys!
          end

          klass = case callback_type.to_sym
            when :wandb then Wandb::XGBoostCallback
            end
          raise "Unknown callback type #{callback_type}" unless klass.present?

          klass.new(conf).tap do |instance|
            instance.instance_variable_set(:@callback_type, callback_type)
          end
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
                                    callbacks: model.callbacks || [],
                                    early_stopping_rounds: hyperparameters.to_h.dig("early_stopping_rounds"))
      end

      def fit_in_batches(batch_size: 1024, batch_key: nil, batch_start: nil, overlap: 1, checkpoint_dir: Rails.root.join("tmp", "xgboost_checkpoints"))
        validate_objective
        ensure_directory_exists(checkpoint_dir)

        # Prepare validation data
        x_valid, y_valid = dataset.valid(split_ys: true)
        d_valid = preprocess(x_valid, y_valid)

        num_iterations = hyperparameters.to_h["n_estimators"]
        early_stopping_rounds = hyperparameters.to_h["early_stopping_rounds"]

        num_batches = dataset.train(batch_size: batch_size, batch_start: batch_start, batch_key: batch_key).count
        iterations_per_batch = num_iterations / num_batches
        stopping_points = (1..num_batches).to_a.map { |n| n * iterations_per_batch }
        stopping_points[-1] = num_iterations

        current_iteration = 0
        current_batch = 0

        callbacks = model.callbacks.nil? ? [] : model.callbacks.dup
        callbacks << ::XGBoost::EvaluationMonitor.new(period: 1)
        early_stopping_rounds = hyperparameters.to_h.dig("early_stopping_rounds")

        # Generate batches without loading full dataset
        batches = dataset.train(split_ys: true, batch_size: batch_size, batch_start: batch_start, batch_key: batch_key)
        prev_xs = []
        prev_ys = []

        while current_iteration < num_iterations
          # Load the next batch
          x_train, y_train = batches.next

          # Add overlap from previous batch if applicable
          merged_x, merged_y = nil, nil
          if prev_xs.any?
            merged_x = Polars.concat([x_train] + prev_xs.flatten)
            merged_y = Polars.concat([y_train] + prev_ys.flatten)
          end

          if overlap > 0
            prev_xs << [x_train]
            prev_ys << [y_train]
            if prev_xs.size > overlap
              prev_xs = prev_xs[1..]
              prev_ys = prev_ys[1..]
            end
          end

          if merged_x.present?
            x_train = merged_x
            y_train = merged_y
          end

          d_train = preprocess(x_train, y_train)
          evals = [[d_train, "train"], [d_valid, "eval"]]

          model_file = current_batch == 0 ? nil : checkpoint_dir.join("#{current_batch - 1}.json").to_s

          @booster = booster_class.new(
            params: hyperparameters.to_h.symbolize_keys,
            cache: [d_train, d_valid],
            model_file: model_file,
          )
          loop_callbacks = callbacks.dup
          if early_stopping_rounds
            loop_callbacks << ::XGBoost::EarlyStopping.new(rounds: early_stopping_rounds)
          end
          cb_container = ::XGBoost::CallbackContainer.new(loop_callbacks)
          @booster = cb_container.before_training(@booster) if current_iteration == 0

          stopping_point = stopping_points[current_batch]
          while current_iteration < stopping_point
            break if cb_container.before_iteration(@booster, current_iteration, d_train, evals)
            @booster.update(d_train, current_iteration)
            break if cb_container.after_iteration(@booster, current_iteration, d_train, evals)
            current_iteration += 1
          end
          current_iteration = stopping_point # In case of early stopping

          @booster.save_model(checkpoint_dir.join("#{current_batch}.json").to_s)
          current_batch += 1
        end

        @booster = cb_container.after_training(@booster)
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
        @xgboost_model = nil
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
            model_file: path,
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
          puts "Preparing data, this may take a minute..."
          x_sample, y_sample = dataset.train(split_ys: true, limit: 5)
          preprocess(x_sample, y_sample) # Ensure we fail fast if the dataset is misconfigured
          x_train, y_train = dataset.train(split_ys: true)
          x_valid, y_valid = dataset.valid(split_ys: true)
          x_test, y_test = dataset.test(split_ys: true)
          @d_train = preprocess(x_train, y_train)
          @d_valid = preprocess(x_valid, y_valid)
          @d_test = preprocess(x_test, y_test)
          puts "Done!"
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
          problematic_columns = orig_xs.schema.select { |k, v| [Polars::Categorical, Polars::String].include?(v) }
          problematic_xs = orig_xs.select(problematic_columns.keys)
          raise %(
            Error building data for XGBoost.
            Apply preprocessing to columns 
            >>>>><<<<<
            #{problematic_columns.keys}
            >>>>><<<<<
            A sample of your dataset:
            #{problematic_xs[0..5]}

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

      def self.hyperparameter_constants
        EasyML::Models::Hyperparameters::XGBoost.hyperparameter_constants
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
        if block_given?
          @booster = yield
        else
          attrs = {
            params: hyperparameters.to_h.symbolize_keys,
          }.deep_compact
          @booster = booster_class.new(**attrs)
        end
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
