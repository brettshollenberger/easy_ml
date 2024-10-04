require "active_support/duration"

module EasyML
  module Support
    module Age
      def self.age(start_time, end_time, format: "human")
        return nil unless start_time && end_time

        age_duration = ActiveSupport::Duration.build((end_time - start_time).to_i)
        age_parts = age_duration.parts

        case format.to_s
        when "human"
          age_duration.inspect
        when "days"
          age_parts[:days]
        when "hours"
          age_parts[:hours]
        when "minutes"
          age_parts[:minutes]
        when "integer"
          age_duration.to_i
        end
      end
    end
  end
end
