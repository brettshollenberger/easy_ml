require "aws-sdk"
require "awesome_print"
require "inertia_rails"
require "jsonapi/serializer"
require "numo/narray"
require "numpy"
require "parallel"
require "polars-df"
require "pycall"
require "optuna"
require "wandb"
require "xgb"
require "rails/engine"
require "activerecord-import"
require "historiographer"
require "resque-batched-job"
require "action_view/template/handlers/erb"

module EasyML
  class Engine < Rails::Engine
    isolate_namespace EasyML

    def root_dir
      Rails.root.join("easy_ml")
    end

    config.autoload_paths += [
      root.join("app/models"),
      root.join("app/models/datasources"),
      root.join("app/models/models"),
      root.join("lib/easy_ml"),
    ]

    config.eager_load_paths += [
      root.join("app/models"),
      root.join("app/models/datasources"),
      root.join("app/models"),
      root.join("app/models/**/"),
      root.join("lib/easy_ml/**/*"),
    ]

    initializer "easy_ml.inflections" do
      require_relative "initializers/inflections"
      EasyML::Initializers::Inflections.inflect
    end

    initializer "easy_ml.enable_string_cache" do
      Polars.enable_string_cache
    end

    unless %w[rake rails bin/rails].include?(File.basename($0)) && %w[generate db:migrate db:drop easy_ml:migration].include?(ARGV.first)
      config.after_initialize do
        Dir.glob(File.expand_path("app/models/easy_ml/datasources/*.rb", EasyML::Engine.root)).each do |file|
          require file
        end
        Dir.glob(File.expand_path("app/models/easy_ml/models/*.rb", EasyML::Engine.root)).each do |file|
          require file
        end
        Dir.glob(File.expand_path("app/models/easy_ml/splitters/*.rb", EasyML::Engine.root)).each do |file|
          require file
        end
        Dir.glob(File.expand_path("app/models/easy_ml/**/*.rb", EasyML::Engine.root)).each do |file|
          require file
        end
      end
    end

    initializer "easy_ml.active_job_config" do
      ActiveSupport.on_load(:active_job) do
        self.queue_adapter = :resque
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

    config.app_middleware.use(
      Rack::Static,
      urls: ["/easy_ml/assets"],
      root: EasyML::Engine.root.join("public"),
    )

    def list_routes
      EasyML::Engine.routes.routes.map { |r| "#{r.name} #{r.path.spec}" }
    end
  end
end
