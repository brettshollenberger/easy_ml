module EasyML
  module Concerns
    module Versionable
      extend ActiveSupport::Concern

      included do
        STRING_FORMAT = "%Y_%m_%d_%H_%M_%S".freeze

        def bump_version(force: false)
          return version if version.present? && !force

          tz = ActiveSupport::TimeZone.new(EasyML::Support::UTC)
          orig_version = version
          prev_version = tz.parse(version.gsub(/_/, "")) if version
          timestamp = Time.current.in_time_zone(EasyML::Support::UTC)
          timestamp = (prev_version + 1.second) if prev_version && compare_versions(timestamp, prev_version)

          self.version = timestamp.strftime(STRING_FORMAT)
        end

        def compare_versions(version1, version2)
          tz = ActiveSupport::TimeZone.new(EasyML::Support::UTC)
          tz.parse(version1.strftime(STRING_FORMAT).gsub(/_/, "")) <= tz.parse(version2.strftime(STRING_FORMAT).gsub(/_/, ""))
        end
      end
    end
  end
end
