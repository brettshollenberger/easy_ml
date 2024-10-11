require "pry"
require "pycall/import"

# Ensure wandb executable isn't set using Ruby context
ENV["WANDB__EXECUTABLE"] = `which python3`.chomp.empty? ? `which python`.chomp : `which python3`.chomp
py_sys = PyCall.import_module("sys")
py_sys.executable = ENV["WANDB__EXECUTABLE"]

module EasyML
  module Loggers
    module Wandb
      include PyCall::Import

      class << self
        # Lazy-load the wandb Python module
        def __pyptr__
          @wandb ||= PyCall.import_module("wandb")
        end

        def Table(*args, **kwargs)
          __pyptr__.Table.new(*args, **kwargs)
        end

        # Expose wandb.plot
        delegate :plot, to: :__pyptr__

        # Expose define_metric
        def define_metric(metric_name, **kwargs)
          __pyptr__.define_metric(name: metric_name.force_encoding("UTF-8"), **kwargs)
        end

        # Expose wandb.Artifact
        def Artifact(*args, **kwargs)
          __pyptr__.Artifact.new(*args, **kwargs)
        end

        # Expose wandb.Error
        delegate :Error, to: :__pyptr__

        # Login to Wandb
        def login(api_key: nil, **kwargs)
          kwargs = kwargs.to_h
          kwargs[:key] = api_key if api_key
          __pyptr__.login(**kwargs)
        end

        # Initialize a new run
        def init(**kwargs)
          run = __pyptr__.init(**kwargs)
          @current_run = Run.new(run)
        end

        # Get the current run
        attr_reader :current_run

        # Log metrics to the current run
        def log(metrics = {})
          raise "No active run. Call Wandb.init() first." unless @current_run

          @current_run.log(metrics.symbolize_keys)
        end

        # Finish the current run
        def finish
          @current_run.finish if @current_run
          @current_run = nil
          __pyptr__.finish
        end

        # Access the Wandb API
        def api
          @api ||= Api.new(__pyptr__.Api.new)
        end
      end

      # Run class
      class Run
        def initialize(run)
          @run = run
        end

        def log(metrics = {})
          metrics.symbolize_keys!
          @run.log(metrics, {})
        end

        def finish
          @run.finish
        end

        def name
          @run.name
        end

        def name=(new_name)
          @run.name = new_name
        end

        def config
          @run.config
        end

        def config=(new_config)
          @run.config.update(PyCall::Dict.new(new_config))
        end
      end

      # Api class
      class Api
        def initialize(api)
          @api = api
        end

        def projects(entity = nil)
          projects = @api.projects(entity)
          projects.map { |proj| Project.new(proj) }
        end

        def project(name, entity = nil)
          proj = @api.project(name, entity)
          Project.new(proj)
        end
      end

      # Project class
      class Project
        def initialize(project)
          @project = project
        end

        def name
          @project.name
        end

        def description
          @project.description
        end
      end
    end
  end
end

require_relative "wandb/xgboost_callback"
