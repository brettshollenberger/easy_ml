module EasyML
  module Data
    class Embeddings
      COMPRESSION_DEFAULT = {
        present: :balanced,
      }

      attr_reader :df, :column, :model, :adapter, :compression,
                  :embeddings, :compressed_embeddings

      def initialize(options = {})
        @df = options[:df]
        @column = options[:column]
        @model = options[:model]
        @config = options[:config] || {}
        @compression = options[:compression] || COMPRESSION_DEFAULT
      end

      def create
        embed
        compress
      end

      def embed
        @embeddings ||= adapter.embed(df, column)
      end

      def compress
        @compressed_embeddings ||= compressor.compress(embeddings)
      end

      private

      def adapter
        @adapter ||= EasyML::Data::Embeddings::Adapters.new(model, config)
      end

      def compressor
        @compressor ||= EasyML::Data::Embeddings::Compressor.new(compression)
      end
    end
  end
end
