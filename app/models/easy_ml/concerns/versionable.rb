module EasyML
  module Concerns
    module Versionable
      extend ActiveSupport::Concern

      included do
        def bump_version(force: false)
          return version if version.present? && !force

          tz = ActiveSupport::TimeZone.new(EasyML::Configuration.timezone)
          prev_version = tz.parse(version.gsub(/_/, "")) if version
          timestamp = Time.current.in_time_zone(EasyML::Configuration.timezone)
          timestamp = (prev_version + 1.second) if prev_version && timestamp <= prev_version

          self.version = timestamp.strftime("%Y_%m_%d_%H_%M_%S")
        end
      end
    end
  end
end
