module EasyML
  module Concerns
    module Versionable
      extend ActiveSupport::Concern

      included do
        def bump_version(force: false)
          return version if version.present? && !force

          prev_version = version
          timestamp = Time.current.in_time_zone(EasyML::Configuration.timezone).strftime("%Y_%m_%d_%H_%M_%S")
          timestamp = (prev_version.to_i + 1).to_s if timestamp.to_i <= prev_version.to_i

          self.version = timestamp
        end
      end
    end
  end
end
