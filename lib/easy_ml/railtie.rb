# lib/railtie.rb
require "rails/railtie"

module EasyML
  class Railtie < Rails::Railtie
    initializer "easy_ml.inflections" do
      require_relative "initializers/inflections"
    end
    # Initialize the generators path
    initializer "easy_ml_railtie.setup_generators" do |app|
      app.config.generators do |g|
        # Add the templates directory to the generator's template paths
        g.templates.unshift File.expand_path("railtie/generators/templates", __dir__)
      end
    end

    # Load generators when the railtie is loaded
    generators_path = File.expand_path("railtie/generators", __dir__)
    generators_dirs = Dir[File.join(generators_path, "**", "*.rb")]
    generators_dirs.each { |file| require file }

    # Ensure that models are loaded after ActiveRecord is initialized
    config.after_initialize do
      require_relative "model"
      require_relative "model_uploader"
    end
  end
end
