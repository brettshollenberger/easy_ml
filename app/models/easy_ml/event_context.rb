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

    def context=(new_context)
      write_attribute(:context, serialize_context(new_context))
      @context = new_context
    end

    def context
      @context ||= deserialize_context(read_attribute(:context))
    end

    private

    def serialize_context(new_context)
      case new_context
      when Hash
        self.format = :json
        new_context.to_json
      when YAML
        self.format = :yaml
        new_context.to_yaml
      when Polars::DataFrame
        self.format = :dataframe
        serialize_dataframe(new_context)
      end
    end

    def deserialize_context(context)
      case format.to_sym
      when :json
        JSON.parse(context)
      when :yaml
        YAML.safe_load(context)
      when :dataframe
        deserialize_dataframe(context)
      end
    end
  end
end
