# == Schema Information
#
# Table name: easy_ml_event_contexts
#
#  id         :bigint           not null, primary key
#  event_id   :bigint           not null
#  context    :jsonb            not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
module EasyML
  class EventContext < ActiveRecord::Base
    self.table_name = "easy_ml_event_contexts"

    belongs_to :event

    validates :data, presence: true
    validates :event, presence: true
  end
end
