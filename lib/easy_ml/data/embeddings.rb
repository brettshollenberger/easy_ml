module EasyML
  module Data
    class Embeddings
      require_relative "embeddings/compressor"
      require_relative "embeddings/adapters"

      attr_reader :df, :column, :model, :adapter, :compression,
                  :embeddings, :compressed_embeddings, :config,
                  :llm, :output_column

      def initialize(options = {})
        @df = options[:df]
        @column = options[:column]
        @output_column = options[:output_column]
        @llm = options[:llm] || "openai"
        @config = options[:config] || {}
        @compression = {
          preset: options.dig(:preset),
          dimensions: options.dig(:dimensions),
        }.compact
      end

      def create
        embed
        compress
      end

      def embed
        @embeddings ||= adapter.embed(df, column, output_column)
      end

      def compress
        @compressed_embeddings ||= compressor.compress(embeddings)
      end

      private

      def adapter
        @adapter ||= EasyML::Data::Embeddings::Adapters.new(llm, config)
      end

      def compressor
        @compressor ||= EasyML::Data::Embeddings::Compressor.new(**compression)
      end
    end
  end
end
