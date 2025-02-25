module EasyML
  class EmbeddingStore
    attr_reader :column, :dataset, :datasource, :full_store, :compressed_store

    def initialize(column)
      @column = column
      @dataset = column&.dataset
      @datasource = dataset&.datasource

      @full_store = EasyML::Data::DatasetManager.new(defaults.merge!(root_dir: embedding_dir(compressed: false)))
      @compressed_store = EasyML::Data::DatasetManager.new(defaults.merge!(root_dir: embedding_dir(compressed: true)))
    end

    def cp(old_version, new_version)
      false
    end

    def wipe
      full_store.wipe
      compressed_store.wipe
    end

    def files
      full_store.files + compressed_store.files
    end

    def empty?(compressed: false)
      if compressed
        compressed_store.empty?
      else
        full_store.empty?
      end
    end

    def compact
      full_store.compact
      compressed_store.compact
    end

    def store(df, compressed: false)
      df = df.select(column.name, column.embedding_column)

      if compressed
        compressed_store.store(df)
      else
        full_store.store(df)
      end
    end

    def query(**kwargs)
      compressed = kwargs.delete(:compressed) || false
      if compressed
        compressed_store.query(**kwargs)
      else
        full_store.query(**kwargs)
      end
    end

    private

    def defaults
      datasource_config = column&.dataset&.datasource&.configuration
      if datasource_config
        options = {
          filenames: "embedding",
          append_only: true,
          primary_key: column.name,
          s3_bucket: datasource_config.dig("s3_bucket") || EasyML::Configuration.s3_bucket,
          s3_prefix: s3_prefix,
          polars_args: datasource_config.dig("polars_args"),
        }.compact
      else
        {}
      end
    end

    def embedding_dir(compressed: false)
      File.join(
        Rails.root,
        "easy_ml/datasets",
        column&.dataset&.name&.parameterize&.gsub("-", "_"),
        "embeddings",
        compressed ? "compressed" : "full",
        column&.name&.parameterize&.gsub("-", "_")
      )
    end

    def s3_prefix
      File.join("datasets", embedding_dir.split("datasets").last)
    end
  end
end
