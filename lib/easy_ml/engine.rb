require "rails/engine"

module EasyML
  class Engine < Rails::Engine
    isolate_namespace EasyML

    initializer "easy_ml.inflections" do
      require_relative "initializers/inflections"
    end

    initializer "easy_ml.setup_generators" do |app|
      app.config.generators do |g|
        g.templates.unshift File.expand_path("../templates", __dir__)
      end
    end

    generators_path = File.expand_path("railtie/generators", __dir__)
    generators_dirs = Dir[File.join(generators_path, "**", "*.rb")]
    generators_dirs.each { |file| require file }

    config.after_initialize do
      require_relative "../../app/models/easy_ml/model"
      require_relative "../../app/models/easy_ml/models"
    end
  end
end
