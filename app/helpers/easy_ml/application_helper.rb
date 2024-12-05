# frozen_string_literal: true

module EasyML
  module ApplicationHelper
    # Override: Returns the engine assets manifest.
    def vite_manifest
      EasyML::Engine.vite_ruby.manifest
    end
  end
end
