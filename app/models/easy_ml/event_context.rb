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
    include EasyML::DataframeSerialization

    self.table_name = "easy_ml_event_contexts"

    belongs_to :event

    validates :context, presence: true
    validates :event, presence: true

    before_save :serialize_context
    after_find :deserialize_context

    private

    def serialize_context
      case format
      when :json
        self.context = context.to_json
      when :yaml
        self.context = context.to_yaml
      when :dataframe
        self.context = serialize_dataframe(context)
      end
    end

    def deserialize_context
      case format
      when :json
        self.context = JSON.parse(context)
      when :yaml
        self.context = YAML.safe_load(context)
      when :dataframe
        self.context = deserialize_dataframe(context)
      end
    end
  end
end
