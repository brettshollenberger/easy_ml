module EasyML
  class SplitterHistory < ActiveRecord::Base
    self.table_name = "easy_ml_splitter_histories"
    include Historiographer::History
  end
end
