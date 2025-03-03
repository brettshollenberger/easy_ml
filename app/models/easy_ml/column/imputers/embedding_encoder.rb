module EasyML
  class Column
    class Imputers
      class EmbeddingEncoder < Base
        encoding_applies :embedding

        def self.description
          "Generate embeddings"
        end

        def transform(df)
          return df unless encode

          df = column.embed(df)
          df
        end
      end
    end
  end
end
