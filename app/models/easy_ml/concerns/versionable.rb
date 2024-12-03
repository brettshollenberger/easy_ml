module EasyML
  module Concerns
    module Versionable
      extend ActiveSupport::Concern

      included do
        def bump_version(force: false)
          return version if version.present? && !force

          timestamp = Time.now.utc.strftime("%Y%m%d%H%M%S")
          self.version = timestamp
        end
      end
    end
  end
end
