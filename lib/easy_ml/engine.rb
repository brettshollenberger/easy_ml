require "aws-sdk"
require "awesome_print"
require "action_controller"
require "inertia_rails"
require "jsonapi/serializer"
require "numo/narray"
require "numpy"
require "parallel"
require "polars-df"
require "pycall"
require "optuna"
require "tailwindcss-rails"
require "wandb"
require "xgb"
require "sidekiq"
require "vite_ruby"
require "rails/engine"
require "activerecord-import"
require "historiographer"

module EasyML
  class Engine < Rails::Engine
    isolate_namespace EasyML

    config.autoload_paths << root.join("app/models")
    config.eager_load_paths << root.join("app/models")
    paths["lib"] << EasyML::Engine.root.join("lib")
    paths["lib"].autoload!

    initializer "easy_ml.inflections" do
      require_relative "initializers/inflections"
      EasyML::Initializers::Inflections.inflect
    end

    initializer "easy_ml.enable_string_cache" do
      Polars.enable_string_cache
    end

    unless %w[rake rails].include?(File.basename($0)) && %w[generate db:migrate].include?(ARGV.first)
      config.after_initialize do
        Dir.glob(
          File.expand_path("app/models/easy_ml/**/*.rb", EasyML::Engine.root)
        ).each do |file|
          require file
        end
      end
    end

    # This tells our demo app where to look for assets like css, js
    initializer "easy_ml.assets" do |app|
      if app.config.respond_to?(:assets)
        app.config.assets.precompile += %w[
          easy_ml/application.js
          easy_ml/application.css
        ]
        app.config.assets.paths << root.join("app", "frontend")
      end
    end

    initializer "easy_ml.setup_generators" do |app|
      generators_path = EasyML::Engine.root.join("lib/easy_ml/railtie/generators")
      generators_dirs = Dir[File.join(generators_path, "**", "*.rb")]
      generators_dirs.each { |file| require file }

      app.config.generators do |g|
        g.templates.unshift File.expand_path("../templates", __dir__)
      end
    end

    delegate :vite_ruby, to: :class

    def self.vite_ruby
      @vite_ruby ||= ViteRuby.new(root: root)
    end

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

    def list_routes
      EasyML::Engine.routes.routes.map { |r| "#{r.name} #{r.path.spec}" }
    end
  end
end
