module EasyML
  class Trainer
    attr_accessor :model, :tuner, :dataset, :tune_every

    def initialize(options = {})
      @tuner = options.dig(:tuner)
      @model = options.dig(:model)
      @dataset = options.dig(:dataset)
      @tune_every = options.dig(:tune_every) || 1.week

      raise "Tuner required" unless tuner.present?
      raise "Model required" unless model.present?
      raise "Dataset required" unless dataset.present?

      @model = @model.class.where(name: @model.name).live&.first || @model
      @model.dataset = @dataset
      @model.dataset.preprocessor.statistics = @model.statistics if @model.is_live
    end

    def train
      dataset.refresh
      # best_params = tuner.tune
      # best_params.each do |k, v|
      #   model.hyperparameters.send("#{k}=", v)
      # end
      model.fit
      binding.pry
      model.save
    end

    def predict(xs)
      model.predict(features(xs))
    end

    def features(df)
      dataset.normalize(df, split_ys: true)
    end
  end
end
