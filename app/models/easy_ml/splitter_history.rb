# == Schema Information
#
# Table name: easy_ml_splitter_histories
#
#  id                 :bigint           not null, primary key
#  splitter_id        :integer          not null
#  splitter_type      :string           not null
#  configuration      :json
#  dataset_id         :integer          not null
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#  history_started_at :datetime         not null
#  history_ended_at   :datetime
#  history_user_id    :integer
#  snapshot_id        :string
#
module EasyML
  class SplitterHistory < ActiveRecord::Base
    self.table_name = "easy_ml_splitter_histories"
    include Historiographer::History
  end
end
