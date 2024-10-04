require "active_support/concern"
require "fileutils"

module EasyML
  module Support
    module GitIgnorable
      extend ActiveSupport::Concern

      included do
        class_attribute :gitignore_attributes, default: {}

        def self.set_gitignore_callbacks(attribute, &block)
          gitignore_attributes[attribute] = block

          prepend GitignoreInitializer
        end
      end

      module GitignoreInitializer
        def initialize(options)
          super
          update_gitignore
        end
      end

      class_methods do
        def gitignore(attribute, &block)
          set_gitignore_callbacks(attribute, &block)
        end
      end

      def update_gitignore
        self.class.gitignore_attributes.each do |attribute, block|
          attribute_value = send(attribute)
          next if attribute_value.blank?

          patterns = block ? block.call(attribute_value) : attribute_value
          next if patterns.nil? || (patterns.respond_to?(:empty?) && patterns.empty?)

          patterns = [patterns] unless patterns.is_a?(Array)
          patterns = relativize(patterns)
          gitignore_path = File.join(Dir.pwd, ".gitignore")

          FileUtils.mkdir_p(File.dirname(gitignore_path))
          FileUtils.touch(gitignore_path) unless File.exist?(gitignore_path)

          existing_content = File.read(gitignore_path).split("\n")
          new_patterns = patterns.reject { |pattern| existing_content.include?(pattern) }
          next if new_patterns.empty?

          new_content = (existing_content + new_patterns).join("\n").strip
          File.write(gitignore_path, new_content)
        end
      end

      private

      # Turn patterns like /Users/xyz/path/to/rails/x/**/* into: x/**/*
      def relativize(patterns)
        patterns.map do |pattern|
          pattern.sub(%r{^#{Regexp.escape(Dir.pwd)}/}, "")
        end
      end
    end
  end
end
