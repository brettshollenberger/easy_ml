require "rails/engine"
require "inertia_rails"
require "vite_ruby"

module EasyML
  class Engine < Rails::Engine
    isolate_namespace EasyML

    initializer "easy_ml.inflections" do
      require_relative "initializers/inflections"
    end

    config.paths.add "lib", eager_load: true

    initializer "easy_ml.assets.precompile" do |app|
      app.config.assets.precompile += %w[
        easy_ml/application.js
        easy_ml/application.css
      ]
    end

    # This tells our demo app where to look for assets like css, js
    initializer "easy_ml.assets" do |app|
      app.config.assets.paths << root.join("app", "frontend")
    end

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

    delegate :vite_ruby, to: :class

    def self.vite_ruby
      @vite_ruby ||= ViteRuby.new(root: root)
    end

    # # Expose compiled assets via Rack::Static when running in the host app.
    # config.app_middleware.use(Rack::Static,
    #                           urls: ["/#{vite_ruby.config.public_output_dir}"],
    #                           root: root.join(vite_ruby.config.public_dir))

    # initializer "vite_rails_engine.proxy" do |app|
    #   if vite_ruby.run_proxy?
    #     app.middleware.insert_before 0, ViteRuby::DevServerProxy, ssl_verify_none: true, vite_ruby: vite_ruby
    #   end
    # end
    # Only use Rack::Static for precompiled assets in non-development environments
    unless Rails.env.development?
      config.app_middleware.use(Rack::Static,
                                urls: ["/#{vite_ruby.config.public_output_dir}"],
                                root: root.join(vite_ruby.config.public_dir))
    end

    initializer "vite_rails_engine.proxy" do |app|
      if vite_ruby.run_proxy?
        # Use Vite proxy in development for live assets
        app.middleware.insert_before 0, ViteRuby::DevServerProxy, ssl_verify_none: true, vite_ruby: vite_ruby
      end
    end

    initializer "vite_rails_engine.logger" do
      config.after_initialize do
        vite_ruby.logger = Rails.logger
      end
    end

    initializer "easy_ml.middleware" do |app|
      # app.middleware.use(
      #   InertiaRails::Middleware,
      #   ssr_enabled: false
      # )
    end
  end
end
