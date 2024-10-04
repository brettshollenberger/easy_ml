module EasyML
  module Models
    class XGBoost < EasyML::Model
      include GlueGun::DSL

      dependency :hyperparameters do |dep|
        dep.set_class EasyML::Models::Hyperparameters::XGBoost
        dep.attribute :batch_size, default: 32
        dep.attribute :learning_rate, default: 0.1
        dep.attribute :max_depth, default: 6
        dep.attribute :n_estimators, default: 100
        dep.attribute :booster, default: "gbtree"
        dep.attribute :objective, default: "reg:squarederror"
      end

      def fit(xs, ys)
        xs = xs.to_a.map(&:values)
        ys = ys.to_a.map(&:values)
        dtrain = ::XGBoost::DMatrix.new(xs, label: ys)
        @model = ::XGBoost.train(hyperparameters.to_h, dtrain)
      end

      def predict(xs)
        @model.predict(xs)
      end

      def save
        # Implement XGBoost-specific model saving logic
        XGBoost.save_model(@model, model_path)
      end

      def load
        # Implement XGBoost-specific model loading logic
        @model = XGBoost.load_model(model_path)
      end
    end
  end
end
