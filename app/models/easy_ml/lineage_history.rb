module EasyML
  class LineageHistory < ActiveRecord::Base
    self.table_name = "easy_ml_lineage_histories"
    include Historiographer::History
  end
end
