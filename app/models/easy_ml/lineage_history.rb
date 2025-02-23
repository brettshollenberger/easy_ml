# == Schema Information
#
# Table name: easy_ml_lineage_histories
#
#  id                 :bigint           not null, primary key
#  easy_ml_lineage_id :integer          not null
#  column_id          :integer          not null
#  key                :string           not null
#  description        :string
#  occurred_at        :datetime
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#  history_started_at :datetime         not null
#  history_ended_at   :datetime
#  history_user_id    :integer
#  snapshot_id        :string
#
module EasyML
  class LineageHistory < ActiveRecord::Base
    self.table_name = "easy_ml_lineage_histories"
    include Historiographer::History
  end
end
