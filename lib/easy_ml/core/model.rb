require "carrierwave"
require_relative "model_core"
require_relative "uploaders/model_uploader"

module EasyML
  module Core
    class Model
      include GlueGun::DSL

      attribute :name, :string
      attribute :version, :string
      attribute :task, :string, default: "regression"
      attribute :metrics, :array
      attribute :ml_model, :string
      attribute :file, :string
      attribute :root_dir, :string
      attribute :objective
      attribute :evaluator
      attribute :evaluator_metric

      include EasyML::Core::ModelCore

      def initialize(options = {})
        super
        apply_defaults
      end
    end
  end
end
