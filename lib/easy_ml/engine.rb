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

    initializer "easy_ml.configure" do |_app|
      EasyML::Configuration.configure do |config|
        config.storage ||= ENV["EASY_ML_STORAGE"] || "file"
        config.s3_access_key_id ||= ENV["S3_ACCESS_KEY_ID"]
        config.s3_secret_access_key ||= ENV["S3_SECRET_ACCESS_KEY"]
        config.s3_bucket ||= ENV["S3_BUCKET"]
        config.s3_region ||= ENV["S3_REGION"]
        config.s3_prefix ||= "easy_ml_models"
      end
    end

    generators_path = File.expand_path("railtie/generators", __dir__)
    generators_dirs = Dir[File.join(generators_path, "**", "*.rb")]
    generators_dirs.each { |file| require file }

    unless %w[rake rails].include?(File.basename($0)) && %w[generate db:migrate].include?(ARGV.first)
      config.after_initialize do
        Dir.glob(
          File.expand_path("app/models/easy_ml/**/*.rb", EasyML::Engine.root)
        ).each do |file|
          require file
        end
      end
    end
  end
end
