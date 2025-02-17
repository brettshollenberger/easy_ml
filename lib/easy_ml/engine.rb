require "aws-sdk"
require "awesome_print"
require "rails/all"
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
require "zhong"
require "dotenv"

module EasyML
  class Engine < Rails::Engine
    isolate_namespace EasyML

    Dotenv.load if File.exist?(".env")

    def root_dir
      Rails.root.join("easy_ml")
    end

    config.autoload_paths += [
      root.join("app/models"),
      root.join("app/models/datasources"),
      root.join("app/models/models"),
      root.join("lib/easy_ml"),
      root.join("app/evaluators"),
    ]

    config.eager_load_paths += [
      root.join("app/models"),
      root.join("app/models/datasources"),
      root.join("app/models"),
      root.join("app/models/**/"),
      root.join("lib/easy_ml/**/*"),
      root.join("app/evaluators"),
    ]

    initializer "easy_ml.initializers" do
      EasyML::Initializers::Inflections.inflect
    end

    initializer "easy_ml.enable_string_cache" do
      Polars.enable_string_cache
    end

    if %w[db:create db:migrate db:migrate:status db:setup db:drop assets:precompile].include?(ARGV.first)
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
        Dir.glob(File.expand_path("app/evaluators/**/*.rb", EasyML::Engine.root)).each do |file|
          require file
        end
      end
    end

    unless %w[db:create db:migrate db:migrate:status db:setup db:drop assets:precompile].include?(ARGV.first)
      initializer "easy_ml.configure_secrets" do
        EasyML::Configuration.configure do |config|
          raise "S3_ACCESS_KEY_ID is missing. Set ENV['S3_ACCESS_KEY_ID']" unless ENV["S3_ACCESS_KEY_ID"]
          raise "S3_SECRET_ACCESS_KEY is missing. Set ENV['S3_SECRET_ACCESS_KEY']" unless ENV["S3_SECRET_ACCESS_KEY"]

          config.s3_access_key_id = ENV["S3_ACCESS_KEY_ID"]
          config.s3_secret_access_key = ENV["S3_SECRET_ACCESS_KEY"]
          config.s3_region = ENV["S3_REGION"] ? ENV["S3_REGION"] : "us-east-1"
          config.timezone = ENV["TIMEZONE"].present? ? ENV["TIMEZONE"] : "America/New_York"
          config.wandb_api_key = ENV["WANDB_API_KEY"] if ENV["WANDB_API_KEY"]
        end
      end
    end

    initializer "easy_ml.check_pending_migrations" do
      if defined?(Rails::Server)
        config.after_initialize do
          if EasyML.pending_migrations?
            puts "\e[33mWARNING: You have pending EasyML migrations. Run 'rails generate easy_ml:migration' to add them.\e[0m"
          end
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

    if ENV["EASY_ML_DEV"]
      require "vite_ruby"
      require "vite_rails"

      def vite_ruby
        @vite_ruby ||= ViteRuby.new(root: root)
      end

      puts "Running dev proxy"
      config.app_middleware.insert_before 0,
        ViteRuby::DevServerProxy,
        vite_ruby: vite_ruby,
        ssl_verify_none: true
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
