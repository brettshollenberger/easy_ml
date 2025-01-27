require File.expand_path("boot", __dir__)

require "rails/all"
Bundler.require(:default, Rails.env)

module Internal
  class Application < Rails::Application
    config.load_defaults 7.0
  end
end
