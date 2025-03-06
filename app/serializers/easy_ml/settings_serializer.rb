require "jsonapi/serializer"

module EasyML
  class SettingsSerializer
    include JSONAPI::Serializer

    attributes *EasyML::Settings.configuration_attributes

    attribute :version do |object|
      EasyML::VERSION
    end

    attribute :git_sha do |object|
      # Get git SHA of the main app
      if Rails.root.join('.git').exist?
        sha = `cd #{Rails.root} && git rev-parse HEAD`.strip
        sha.presence || "Git SHA unavailable"
      else
        "Not a git repository"
      end
    rescue
      "Error determining git SHA"
    end
  end
end
