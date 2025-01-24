# frozen_string_literal: true

module EasyML
  module ApplicationHelper
    # Override: Returns the engine assets manifest.
    def easy_ml_manifest
      ViteRuby.new(root: EasyML::Engine.root).manifest
    end

    def prod_script_tags
      vite_manifest = Thread.current[:vite_manifest] ||= JSON.parse(File.read(EasyML::Engine.root.join("public/easy_ml/assets/.vite/manifest.json")))
      entrypoint = vite_manifest.dig("entrypoints/Application.tsx")
      application_js = entrypoint.dig("file")
      css_files = entrypoint.dig("css")

      # Create HTML tags for the JavaScript and CSS using Rails tag helpers
      tags = []
      tags << javascript_include_tag("/easy_ml/assets/#{application_js}", type: "module")
      css_files.each do |css_file|
        tags << stylesheet_link_tag("/easy_ml/assets/#{css_file}")
      end
      tags.join("\n").html_safe
    end
  end
end
