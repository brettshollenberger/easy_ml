# Background:

EasyML is a framework for automating machine learning pipelines.

# Brainstorm:

Today we will implement embeddings as a preprocessing step.

Our goals:

1. Add `is_primary_key` to the `Column` model, and to frontend

2. Allow preprocessing steps to use embeddings as a parameter:

```ruby
preprocessing_steps: {
  training: {
    method: :embedding, # This is valid
    params: {
      embedding: { # And this is valid
        model: "text-embedding-model-name",
        dimension: 1024,
      }
    }
  }
}

preprocessing_steps: {
  training: {
    method: :categorical,
    params: {
      embedding: { # It can also be used for other types, but we cannot also use one_hot/ordinal_encoding
        model: "text-embedding-model-name",
        dimension: 1024,
      }
    }
  }
}
```

3. Create EmbeddingStore using append-only DatasetManager:

```ruby
module EasyML
  class EmbeddingStore < EasyML::Data::DatasetManager
    attr_reader :column
    def initialize(column)
      @column = column

      datasource_config = column.dataset.datasource.configuration || {}

      options = {
        root_dir: column_dir,
        filenames: "column",
        append_only: true,
        primary_key: column.dataset.primary_key,
        s3_bucket: datasource_config.dig("s3_bucket") || EasyML::Configuration.s3_bucket,
        s3_prefix: s3_prefix,
        polars_args: datasource_config.dig("polars_args"),
      }.compact
      super(options)
    end

    private

    def column_dir
      File.join(
        Rails.root,
        "easy_ml/datasets",
        column.dataset.name.parameterize.gsub("-", "_"),
        "columns",
        column.name.parameterize.gsub("-", "_")
      )
    end

    def s3_prefix
      File.join("datasets", column_dir.split("datasets").last)
    end
  end
end
```

4. Add `EmbeddingModel` with adapters, e.g. for `OpenAI` and `Ollama`

5. Add Embedding imputer:

```ruby
module EasyML
  class Column
    module Imputers
      class Embedding < Base
        def transform(df)
          store = EmbeddingStore.new(column.dataset, column)

          # Get configuration
          primary_key_col = params["primary_key_column"]
          text_col = params["text_column"]

          # Create lookup of primary key -> text value
          text_values = df.select([primary_key_col, text_col])
                         .to_hash
                         .each_with_object({}) do |(pk, text), hash|
                           hash[pk] = text
                         end

          # Query existing embeddings
          existing_embeddings = store.query(text_values.keys, text_values)

          # Identify records needing new embeddings
          new_records = text_values.reject { |pk, _| existing_embeddings.key?(pk) }

          if new_records.any?
            # Generate new embeddings
            new_embeddings = generate_embeddings(
              new_records.values,
              model: params["model"]
            )

            # Create dataframe with new embeddings
            new_embeddings_df = Polars.DataFrame.new(
              primary_key: new_records.keys,
              text: new_records.values,
              embedding: new_embeddings
            )

            # Append new embeddings to store
            store.append(new_embeddings_df)

            # Merge with existing embeddings
            existing_embeddings.merge!(
              new_embeddings_df.to_hash.each_with_object({}) do |(pk, _, emb), hash|
                hash[pk] = emb
              end
            )
          end

          # Return embeddings in same order as input dataframe
          df[primary_key_col].map { |pk| existing_embeddings[pk] }
        end
      end
    end
  end
end
```
