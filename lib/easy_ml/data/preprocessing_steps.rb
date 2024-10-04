require "fileutils"
require "polars"
require "date"
require "json"
require_relative "preprocessing_steps/utils"

# One of the more involved aspects of managing the ML lifecycle is supporting both a
# live production model and training of a new model.
#
# We want to isolate these steps to separate environments (e.g. web servers allow ONLY prediction logic,
# while workers and local dev environment support ONLY training logic).
#
module EasyML::Data
  class PreprocessingSteps
    include EasyML::Data::PreprocessingSteps::Utils

    attr_accessor :directory, :preprocessing_steps, :verbose

    def initialize(directory: nil, preprocessing_steps: {}, verbose: false)
      @directory = directory
      @preprocessing_steps = standardize_config(preprocessing_steps).with_indifferent_access
      @verbose = verbose
    end

    def fit(df)
      development.fit(df)
    end

    # Options:
    # 1) When running production inference (inference: true, environment: "production")
    # 2) When running training (inference: false, environment: "development")
    # 3) When testing newly trained model (inference: true, environment: "development")
    #
    def postprocess(df, inference: false, environment: "production")
      environment = environment.to_s

      if environment == "development"
        development.postprocess(df, inference: inference)
      elsif environment == "production"
        production.postprocess(df, inference: true)
      end
    end

    # TODO: Cleanup implementation
    def statistics(environment = "production")
      environment = environment.to_s

      if environment == "production"
        production.statistics
      elsif environment == "development"
        development.statistics
      end
    end

    def productionize
      production.delete
      development.move("production")
      reload
    end

    def reload
      @production = nil
      @development = nil
      production
      development
    end

    def production
      @production ||= Preprocessor.new(
        directory: File.join(directory, "production"),
        preprocessing_steps: preprocessing_steps,
        verbose: verbose,
        environment: "production"
      )
    end

    def development
      @development ||= Preprocessor.new(
        directory: File.join(directory, "development"),
        preprocessing_steps: preprocessing_steps,
        verbose: verbose,
        environment: "development"
      )
    end
  end
end
