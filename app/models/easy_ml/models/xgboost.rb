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
          params.map!(&:deep_symbolize_keys)
          unless params.any? { |c| c[:callback_type]&.to_sym == :wandb }
            params << {
              callback_type: :wandb,
              project_name: model.name,
              log_feature_importance: false,
              define_metric: false,
            }
          end

          unless params.any? { |c| c[:callback_type]&.to_sym == :evals_callback }
            params << {
              callback_type: :evals_callback,
            }
          end

          unless params.any? { |c| c[:callback_type]&.to_sym == :progress_callback }
            params << {
              callback_type: :progress_callback,
            }
          end

          params.sort_by! { |c| c[:callback_type] == :evals_callback ? 0 : 1 }
        end
      end

      def build_callbacks(params)
        return [] unless params.is_a?(Array)

        add_auto_configurable_callbacks(params)

        params.uniq! { |c| c[:callback_type] }

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
            when :evals_callback then EasyML::Models::XGBoost::EvalsCallback
            when :progress_callback then EasyML::Models::XGBoost::ProgressCallback
            end
          raise "Unknown callback type #{callback_type}" unless klass.present?

          klass.new(conf).tap do |instance|
            instance.instance_variable_set(:@callback_type, callback_type)
            instance.send(:model=, model) if instance.respond_to?(:model=)
          end
        end
      end

      def after_tuning
        model.callbacks.each do |callback|
          callback.after_tuning if callback.respond_to?(:after_tuning)
        end
      end

      def cleanup
        model.callbacks.each do |callback|
          callback.cleanup if callback.respond_to?(:cleanup)
        end
      end

      def prepare_callbacks(tuner)
        set_wandb_project(tuner.project_name)

        model.callbacks.each do |callback|
          callback.prepare_callback(tuner) if callback.respond_to?(:prepare_callback)
        end
      end

      def set_wandb_project(project_name)
        wandb_callback = model.callbacks.detect { |cb| cb.class == Wandb::XGBoostCallback }
        return unless wandb_callback.present?
        wandb_callback.project_name = project_name
      end

      def get_wandb_project
        wandb_callback = model.callbacks.detect { |cb| cb.class == Wandb::XGBoostCallback }
        return nil unless wandb_callback.present?
        wandb_callback.project_name
      end

      def delete_wandb_project
        wandb_callback = model.callbacks.detect { |cb| cb.class == Wandb::XGBoostCallback }
        return nil unless wandb_callback.present?
        wandb_callback.project_name = nil
      end

      def is_fit?
        @booster.present? && @booster.feature_names.any?
      end

      attr_accessor :progress_callback

      def fit(tuning: false, x_train: nil, y_train: nil, x_valid: nil, y_valid: nil, &progress_block)
        validate_objective

        d_train, d_valid, = prepare_data if x_train.nil?

        evals = [[d_train, "train"], [d_valid, "eval"]]
        self.progress_callback = progress_block
        set_default_wandb_project_name unless tuning
        @booster = base_model.train(hyperparameters.to_h,
                                    d_train,
                                    evals: evals,
                                    num_boost_round: hyperparameters["n_estimators"],
                                    callbacks: model.callbacks,
                                    early_stopping_rounds: hyperparameters.to_h.dig("early_stopping_rounds"))
        delete_wandb_project unless tuning
        return @booster
      end

      def set_default_wandb_project_name
        return if get_wandb_project.present?

        started_at = EasyML::Support::UTC.now
        project_name = "#{model.name}_#{started_at.strftime("%Y_%m_%d_%H_%M_%S")}"
        set_wandb_project(project_name)
      end

      def fit_in_batches(tuning: false, batch_size: 1024, batch_key: nil, batch_start: nil, batch_overlap: 1, checkpoint_dir: Rails.root.join("tmp", "xgboost_checkpoints"))
        validate_objective
        ensure_directory_exists(checkpoint_dir)
        set_default_wandb_project_name unless tuning

        # Prepare validation data
        x_valid, y_valid = dataset.valid(split_ys: true, select: dataset.col_order)
        d_valid = preprocess(x_valid, y_valid)

        num_iterations = hyperparameters.to_h[:n_estimators]
        early_stopping_rounds = hyperparameters.to_h[:early_stopping_rounds]

        num_batches = dataset.train(batch_size: batch_size, batch_start: batch_start, batch_key: batch_key).count
        iterations_per_batch = num_iterations / num_batches
        stopping_points = (1..num_batches).to_a.map { |n| n * iterations_per_batch }
        stopping_points[-1] = num_iterations

        current_iteration = 0
        current_batch = 0

        callbacks = model.callbacks.nil? ? [] : model.callbacks.dup
        callbacks << ::XGBoost::EvaluationMonitor.new(period: 1)

        # Generate batches without loading full dataset
        batches = dataset.train(split_ys: true, batch_size: batch_size, batch_start: batch_start, batch_key: batch_key, select: dataset.col_order)
        prev_xs = []
        prev_ys = []

        while current_iteration < num_iterations
          # Load the next batch
          x_train, y_train = batches.next

          # Add batch_overlap from previous batch if applicable
          merged_x, merged_y = nil, nil
          if prev_xs.any?
            merged_x = Polars.concat([x_train] + prev_xs.flatten)
            merged_y = Polars.concat([y_train] + prev_ys.flatten)
          end

          if batch_overlap > 0
            prev_xs << [x_train]
            prev_ys << [y_train]
            if prev_xs.size > batch_overlap
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
        delete_wandb_project unless tuning
        return @booster
      end

      def weights(model_file)
        return nil unless model_file.present? && model_file.fit?

        JSON.parse(model_file.read)
      end

      def set_weights(model_file, weights)
        raise ArgumentError, "Weights must be provided" unless weights.present?

        # Create a temp file with the weights
        temp_file = Tempfile.new(["xgboost_weights", ".json"])
        begin
          temp_file.write(weights.to_json)
          temp_file.close

          # Load the weights into a new booster
          initialize_model do
            attrs = {
              params: hyperparameters.to_h.symbolize_keys.compact,
              model_file: temp_file.path,
            }.compact
            booster_class.new(**attrs)
          end
        ensure
          temp_file.unlink
        end
      end

      def predicting(xs, &block)
        raise "No trained model! Train a model before calling predict" unless @booster.present?
        raise "Cannot predict on nil — XGBoost" if xs.nil?

        begin
          @predicting = true
          y_pred = yield(preprocess(xs))
          @predicting = false
          y_pred
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
      end

      def predict(xs)
        y_pred = predicting(xs) do |d_matrix|
          @booster.predict(d_matrix)
        end

        case task.to_sym
        when :classification
          to_classification(y_pred)
        else
          y_pred
        end
      end

      def predict_proba(xs)
        y_pred = predicting(xs) do |d_matrix|
          @booster.predict(d_matrix)
        end

        if y_pred.first.is_a?(Array)
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
            params: hyperparameters.to_h.symbolize_keys.compact,
            model_file: path,
          }.compact
          booster_class.new(**attrs)
        end
      end

      def external_model
        @booster
      end

      def external_model=(booster)
        @booster = booster
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
          col_order = dataset.col_order
          x_sample, y_sample = dataset.processed.train(split_ys: true, limit: 5, select: col_order, lazy: true)
          preprocess(x_sample, y_sample) # Ensure we fail fast if the dataset is misconfigured
          x_train, y_train = dataset.processed.train(split_ys: true, select: col_order, lazy: true)
          x_valid, y_valid = dataset.processed.valid(split_ys: true, select: col_order, lazy: true)
          x_test, y_test = dataset.processed.test(split_ys: true, select: col_order, lazy: true)
          @d_train = preprocess(x_train, y_train)
          @d_valid = preprocess(x_valid, y_valid)
          @d_test = preprocess(x_test, y_test)
        end

        [@d_train, @d_valid, @d_test]
      end

      def trainable?
        untrainable_columns.empty?
      end

      def untrainable_columns
        model.dataset.refresh if model.dataset.processed.nil?

        model.dataset.list_nulls(
          model.dataset.processed.data(lazy: true)
        )
      end

      def explode_embeddings(df)
        embedding_cols = dataset.columns.where.not(hidden: true).select(&:embedded?)
        # Create all extraction expressions at once
        select_expressions = []

        # Retain all non-embedding columns
        base_cols = df.schema.keys - embedding_cols.map(&:embedding_column)
        select_expressions << Polars.col(base_cols)

        # Add all embedding extraction expressions
        embedding_cols.each do |col|
          dims = col.n_dimensions || 1
          (0...dims).each do |i|
            # Create a single expression that extracts one element
            select_expressions << Polars.col(col.embedding_column).list.get(i).alias("#{col.embedding_column}_#{i}")
          end
        end

        df.select(select_expressions)
      end

      def preprocess(xs, ys = nil)
        return xs if xs.is_a?(::XGBoost::DMatrix)
        lazy = xs.is_a?(Polars::LazyFrame)
        return xs if (lazy ? xs.limit(1).collect : xs).shape[0] == 0

        weights_col = (model.weights_column.nil? || model.weights_column.blank?) ? nil : model.weights_column

        if weights_col == model.dataset.target
          raise ArgumentError, "Weight column cannot be the target column"
        end

        # Extract feature columns (all columns except label and weight)
        feature_cols = xs.columns
        feature_cols -= [weights_col] if weights_col

        # Get features, labels and weights
        exploded = explode_embeddings(xs.select(feature_cols))
        feature_cols = exploded.columns
        features = lazy ? exploded.collect.to_numo : exploded.to_numo

        unless @predicting
          weights = weights_col ? (lazy ? xs.select(weights_col).collect.to_numo : xs.select(weights_col).to_numo) : nil
          weights = weights.flatten if weights
        end
        if ys.present?
          ys = ys.is_a?(Array) ? Polars::Series.new(ys) : ys
          labels = lazy ? ys.collect.to_numo.flatten : ys.to_numo.flatten
        else
          labels = nil
        end

        kwargs = {
          label: labels,
          weight: weights,
        }.compact

        begin
          ::XGBoost::DMatrix.new(features, **kwargs).tap do |dmatrix|
            dmatrix.feature_names = feature_cols
          end
        rescue StandardError => e
          problematic_columns = xs.schema.select { |k, v| [Polars::Categorical, Polars::String].include?(v) }
          problematic_xs = lazy ? xs.lazy.select(problematic_columns.keys).collect : xs.select(problematic_columns.keys)
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
