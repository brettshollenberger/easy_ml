module EasyML
  module Data
    class Embeddings
      require_relative "embeddings/compressor"
      require_relative "embeddings/adapters"

      attr_reader :df, :column, :model, :adapter, :compression,
                  :embeddings, :compressed_embeddings, :config,
                  :llm, :output_column, :preset, :dimensions

      def initialize(options = {})
        @df = options[:df]
        @column = options[:column]
        @output_column = options[:output_column]
        @llm = options[:llm] || "openai"
        @config = options[:config] || {}
        @preset = options.dig(:preset)
        @dimensions = options.dig(:dimensions)
        @pca_model = options.dig(:pca_model)
      end

      def create
        embed
        compress(embeddings)
      end

      def embed
        @embeddings ||= adapter.embed(df, column, output_column)
      end

      def compress(embeddings, fit: false)
        @compressed_embeddings ||= compressor.compress(embeddings, column, output_column, fit: fit)
      end

      def pca_model
        return @pca_model if @pca_model.present?
        return @compressor.pca_model if @compressor

        nil
      end

      private

      def adapter
        @adapter ||= EasyML::Data::Embeddings::Adapters.new(llm, config)
      end

      def compressor_args
        {
          preset: preset,
          dimensions: dimensions,
          pca_model: pca_model,
        }.compact
      end

      def compressor
        @compressor ||= EasyML::Data::Embeddings::Compressor.new(compressor_args)
      end
    end
  end
end
