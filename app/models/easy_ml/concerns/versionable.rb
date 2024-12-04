module EasyML
  module Concerns
    module Versionable
      extend ActiveSupport::Concern

      included do
        def bump_version(force: false)
          return version if version.present? && !force

          prev_version = version
          timestamp = Time.now.utc.strftime("%Y%m%d%H%M%S")
          timestamp = (timestamp.to_i + 1).to_s if timestamp == prev_version

          self.version = timestamp
        end
      end
    end
  end
end