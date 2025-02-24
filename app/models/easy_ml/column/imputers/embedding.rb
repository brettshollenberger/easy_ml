module EasyML
  class Column
    class Imputers
      class Embedding < Base
        method_applies :embedding

        def self.description
          "Generate embeddings"
        end

        def transform(df)
          df = column.embed(df)
          df
        end
      end
    end
  end
end
