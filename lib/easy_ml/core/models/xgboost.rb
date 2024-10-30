require "wandb"
require_relative "hyperparameters"
module EasyML
  module Core
    module Models
      class XGBoost < EasyML::Core::Model
        include EasyML::FileSupport
        Hyperparameters = EasyML::Models::Hyperparameters::XGBoost

        OBJECTIVES = {
          classification: {
            binary: %w[binary:logistic binary:hinge],
            multi_class: %w[multi:softmax multi:softprob]
          },
          regression: %w[reg:squarederror reg:logistic]
        }

        attribute :evaluator
        attribute :early_stopping_rounds
        attr_accessor :model, :booster

        dependency :callbacks, { array: true } do |dep|
          dep.option :wandb do |opt|
            opt.set_class Wandb::XGBoostCallback
            opt.bind_attribute :log_model, default: false
            opt.bind_attribute :log_feature_importance, default: true
            opt.bind_attribute :importance_type, default: "gain"
            opt.bind_attribute :define_metric, default: true
            opt.bind_attribute :project_name
          end
        end

        dependency :hyperparameters do |dep|
          # gbtree option
          dep.option :gbtree do |option|
            option.set_class Hyperparameters::GBTree
            option.bind_attribute :learning_rate      # Common
            option.bind_attribute :max_depth          # Common
            option.bind_attribute :n_estimators       # Common
            option.bind_attribute :booster            # Common
            option.bind_attribute :objective          # Common
            option.bind_attribute :gamma              # GBTree-specific
            option.bind_attribute :min_child_weight   # GBTree-specific
            option.bind_attribute :subsample          # GBTree-specific
            option.bind_attribute :colsample_bytree   # GBTree-specific
            option.bind_attribute :colsample_bylevel  # GBTree-specific
            option.bind_attribute :colsample_bynode   # GBTree-specific
            option.bind_attribute :lambda             # Regularization (Common)
            option.bind_attribute :alpha              # Regularization (Common)
            option.bind_attribute :tree_method        # GBTree-specific
            option.bind_attribute :scale_pos_weight   # Class imbalance (Common for classification)
          end

          # dart option
          dep.option :dart do |option|
            option.set_class Hyperparameters::Dart
            option.bind_attribute :learning_rate      # Common
            option.bind_attribute :max_depth          # Common
            option.bind_attribute :n_estimators       # Common
            option.bind_attribute :booster            # Common
            option.bind_attribute :objective          # Common
            option.bind_attribute :rate_drop          # DART-specific
            option.bind_attribute :skip_drop          # DART-specific
            option.bind_attribute :sample_type        # DART-specific
            option.bind_attribute :normalize_type     # DART-specific
            option.bind_attribute :subsample          # GBTree-like (shared with gbtree)
            option.bind_attribute :colsample_bytree   # GBTree-like (shared with gbtree)
            option.bind_attribute :lambda             # Regularization (Common)
            option.bind_attribute :alpha              # Regularization (Common)
          end

          # gblinear option
          dep.option :gblinear do |option|
            option.set_class Hyperparameters::GBLinear
            option.bind_attribute :learning_rate      # Common
            option.bind_attribute :booster            # Common
            option.bind_attribute :n_estimators       # Common
            option.bind_attribute :lambda             # Regularization (Common)
            option.bind_attribute :alpha              # Regularization (Common)
            option.bind_attribute :updater            # GBLinear-specific
            option.bind_attribute :feature_selector   # GBLinear-specific
          end

          # multi-class classification option
          dep.option :multiclass do |option|
            option.set_class Hyperparameters::MultiClass
            option.bind_attribute :learning_rate      # Common
            option.bind_attribute :max_depth          # Common
            option.bind_attribute :n_estimators       # Common
            option.bind_attribute :booster            # Common
            option.bind_attribute :objective          # Multi-class-specific
            option.bind_attribute :num_class          # Multi-class-specific
            option.bind_attribute :colsample_bytree   # Common (shared with gbtree)
            option.bind_attribute :subsample          # Common (shared with gbtree)
            option.bind_attribute :lambda             # Regularization (Common)
            option.bind_attribute :alpha              # Regularization (Common)
          end

          # binary classification option
          dep.option :binary do |option|
            option.set_class Hyperparameters::BinaryClassification
            option.bind_attribute :learning_rate      # Common
            option.bind_attribute :max_depth          # Common
            option.bind_attribute :n_estimators       # Common
            option.bind_attribute :booster            # Common
            option.bind_attribute :objective          # Binary-specific
            option.bind_attribute :scale_pos_weight   # Class imbalance (Binary-specific)
            option.bind_attribute :colsample_bytree   # Common (shared with gbtree)
            option.bind_attribute :subsample          # Common (shared with gbtree)
            option.bind_attribute :lambda             # Regularization (Common)
            option.bind_attribute :alpha              # Regularization (Common)
          end

          # regression option
          dep.option :regression do |option|
            option.set_class Hyperparameters::Regression
            option.bind_attribute :learning_rate      # Common
            option.bind_attribute :max_depth          # Common
            option.bind_attribute :n_estimators       # Common
            option.bind_attribute :booster            # Common
            option.bind_attribute :objective          # Regression-specific
            option.bind_attribute :colsample_bytree   # Common (shared with gbtree)
            option.bind_attribute :subsample          # Common (shared with gbtree)
            option.bind_attribute :lambda             # Regularization (Common)
            option.bind_attribute :alpha              # Regularization (Common)
          end

          # Conditional logic for selecting the class based on the booster
          dep.when do |dependency|
            case dependency[:booster].to_sym
            when :gbtree
              Hyperparameters::GBTree
            when :dart
              Hyperparameters::Dart
            when :gblinear
              Hyperparameters::GBLinear
            when :multiclass
              Hyperparameters::MultiClass
            when :binary
              Hyperparameters::BinaryClassification
            when :regression
              Hyperparameters::Regression
            else
              raise "Unknown booster type: #{booster}"
            end
          end
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

        def loaded?
          @booster.present?
        end

        def load(path = nil)
          initialize_model do
            booster_class.new(params: hyperparameters.to_h, model_file: path)
          end
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
            x_train, y_train = dataset.train(split_ys: true, limit: 1000)
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

              This may also be due to string-based targets, your targets:
              #{ys[0..5]}
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

        def train(x_train: nil, y_train: nil, x_valid: nil, y_valid: nil)
          validate_objective

          d_train, d_valid, = prepare_data if x_train.nil?
          evals = [[d_train, "train"], [d_valid, "eval"]]
          @booster = base_model.train(hyperparameters.to_h, d_train,
                                      evals: evals,
                                      num_boost_round: hyperparameters["n_estimators"], callbacks: callbacks)
        end

        def train_in_batches
          validate_objective

          # Initialize the model with the first batch
          @model = nil
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

            puts "Batch number #{current_batch}"
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
            @booster = booster_class.new(params: @hyperparameters.to_h, cache: [d_train] + evals.map { |d| d[0] })
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
          @model = model_class.new(n_estimators: @hyperparameters.to_h.dig(:n_estimators))
          @booster = yield
          @model.instance_variable_set(:@booster, @booster)
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
end
