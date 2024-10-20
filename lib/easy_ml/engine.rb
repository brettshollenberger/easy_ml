require "rails/engine"

module EasyML
  class Engine < Rails::Engine
    isolate_namespace EasyML

    initializer "easy_ml.inflections" do
      require_relative "initializers/inflections"
    end

    config.paths.add "lib", eager_load: true

    initializer "easy_ml.setup_generators" do |app|
      app.config.generators do |g|
        g.templates.unshift File.expand_path("../templates", __dir__)
      end
    end

    generators_path = File.expand_path("railtie/generators", __dir__)
    generators_dirs = Dir[File.join(generators_path, "**", "*.rb")]
    generators_dirs.each { |file| require file }

    unless %w[rake rails].include?(File.basename($0)) && %w[generate db:migrate].include?(ARGV.first)
      config.after_initialize do
        require File.expand_path("app/models/easy_ml/model", EasyML::Engine.root)
        require File.expand_path("app/models/easy_ml/models", EasyML::Engine.root)
      end
    end
  end
end
