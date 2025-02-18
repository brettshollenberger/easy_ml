# Background:

EasyML is a framework for automating machine learning pipelines.

# Rules:

## Do No Harm

- Do not remove any code that seems to be irrelevant to your task. You do not have full context of the application, so you should err on the side of NOT removing code, unless the code is clearly duplication.
- Look for any files you might need
- If you have any questions, DO NOT WRITE CODE. Ask the question. I will be happy to answer all your questions to your satisfaction before you start.
- Measure twice, cut once!

# Feature:

Add support for column-level embeddings in EasyML with efficient storage, caching, and querying capabilities. The implementation leverages existing preprocessing patterns while introducing new storage mechanisms optimized for embeddings.

## Key Components

1. Column Configuration

```ruby
preprocessing_steps: {
  params: {
    embedding: {
      model: "text-embedding-model-name",
      dimension: 1024,
    }
  },
}
```

Column will also be updated with an `is_primary_key` boolean flag, like `column#is_target` and `column#is_date_column`. Embeddings will then query the EmbeddingStore using columns.where(is_primary_key: true) + embedding_column.value to retrieve embeddings.

2. EmbeddingStore Class

The EmbeddingStore class needs to function as an append-only structure, which partitions data by primary key and stores embeddings in a Parquet file.

It should leverage Polars::Reader for existing querying capability, and focus instead on storage and appending new data.

Here is a dummy implementation that should probably be improved using `sink_parquet` or similar. I would also like to NOT have to rewrite the entire file every time a new embedding is added.

```ruby
module EasyML
  class EmbeddingStore
    def initialize(dataset, column)
      @dataset = dataset
      @column = column
      @primary_key_column = column.preprocessing_steps.dig("embedding", "primary_key_column")
    end

    # Or simply delegate to a polars reader
    def query(primary_keys, text_values)
      Polars::Reader.query(filter: Polars.col(@primary_key_column).is_in(primary_keys) & Polars.col(@column.name).is_in(text_values))
    end

    def append(new_embeddings_df)
      path = current_embeddings_path

      if File.exist?(path)
        # Append to existing file
        existing_df = Polars.read_parquet(path)
        combined_df = existing_df.vstack(new_embeddings_df)
        # Deduplicate based on primary key + text value
        combined_df = combined_df.unique(subset: [primary_key_column, text_column])
        combined_df.write_parquet(path)
      else
        # Create new file
        FileUtils.mkdir_p(File.dirname(path))
        new_embeddings_df.write_parquet(path)
      end
    end

    private

    def current_embeddings_path
      File.join(store_dir, "embeddings.parquet")
    end

    def store_dir
      File.join(
        Rails.root,
        "easy_ml/datasets",
        dataset.name.parameterize.gsub("-", "_"),
        "embeddings",
        column.name.parameterize.gsub("-", "_")
      )
    end

    def remote_store_dir
      File.join(
        "datasets",
        dataset.name.parameterize.gsub("-", "_"),
        "embeddings",
        column.name.parameterize.gsub("-", "_")
      )
    end
  end
end
```

3. Embedding Imputer

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

Implementation Steps

1. Database Changes

- No schema changes required
- Embeddings stored in Parquet files, similar to feature store

2. New Classes (lib/easy_ml/)

- embedding_store.rb: Manages embedding storage and retrieval
- column/imputers/embedding.rb: Handles embedding generation and caching

3. Column Model Updates

- Add validation for embedding preprocessing configuration
- Ensure primary_key_column and text_column are specified
- Add helper methods for checking embedding status

4. Storage Structure
   easy_ml/datasets/
   {dataset_name}/
   embeddings/
   {column_name}/
   embeddings.parquet # Contains: primary_key, text_value, embedding

5. UI Updates

- Add embedding configuration to column settings
- Show embedding status in column list
- Display embedding dimension in column details

Key Features

1. Efficient Storage

- Append-only Parquet files
- Deduplication based on primary key + text value
- Automatic remote storage sync

2. Smart Caching

- Only compute embeddings for new or changed records
- Cache invalidation based on primary key + text value
- No unnecessary recomputation during dataset refreshes

3. Deployment Support

- Embeddings included in model deployment
- Remote storage integration
- No dependency on feature versioning

4. Performance Optimization

- Batch processing for new embeddings
- Efficient Parquet file operations
- Minimal memory footprint

5. Testing Requirements

- Unit Tests
- EmbeddingStore operations
- Embedding imputer functionality
- Cache invalidation logic
- Integration Tests
- End-to-end embedding generation
- Remote storage sync
- Model deployment with embeddings

6. Performance Tests

- Large dataset handling
- Append operations
- Memory usage
