module EasyML
  class ModelFileHistory < ActiveRecord::Base
    self.table_name = "easy_ml_model_file_histories"
    include Historiographer::History
  end
end
