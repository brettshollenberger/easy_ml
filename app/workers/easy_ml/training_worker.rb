module EasyML
  class TrainingWorker < ApplicationWorker
    def perform(model_id)
      model = EasyML::Model.find(model_id)
      model.actually_train
    ensure
      model.update(is_training: false)
    end
  end
end
