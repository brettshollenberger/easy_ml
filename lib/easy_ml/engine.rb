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
require "rake"
require "resque/tasks"

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

    initializer "easy_ml.initializers" do
      Dir.glob(EasyML::Engine.root.join("config/initializers/*.rb")).each { |f| require f }
      EasyML::Initializers::Inflections.inflect
    end

    initializer "easy_ml.enable_string_cache" do
      Polars.enable_string_cache
    end

    if %w[db:migrate db:migrate:status db:setup db:drop assets:precompile].include?(ARGV.first)
      config.eager_load_paths = config.eager_load_paths.without(config.eager_load_paths.map(&:to_s).grep(/easy_ml/).map { |p| Pathname.new(p) })
    else
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
      resque_initializer = File.expand_path("config/initializers/resque.rb", root)
      require resque_initializer if File.exist?(resque_initializer)

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

    if ENV["EASY_ML_DEMO_APP"]
      require "vite_ruby"
      require "vite_rails"

      def vite_ruby
        @vite_ruby ||= ViteRuby.new(root: root)
      end

      puts "Running dev proxy"
      config.app_middleware.insert_before 0, ViteRuby::DevServerProxy, ssl_verify_none: true, vite_ruby: vite_ruby
    else
      config.app_middleware.use(
        Rack::Static,
        urls: ["/easy_ml/assets"],
        root: EasyML::Engine.root.join("public"),
      )
    end

    def list_routes
      EasyML::Engine.routes.routes.map { |r| "#{r.name} #{r.path.spec}" }
    end
  end
end
