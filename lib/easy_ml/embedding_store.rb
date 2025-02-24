module EasyML
  class EmbeddingStore < EasyML::Data::DatasetManager
    attr_reader :column, :dataset, :datasource

    def initialize(column)
      @column = column
      @dataset = column&.dataset
      @datasource = dataset&.datasource

      datasource_config = column&.dataset&.datasource&.configuration
      if datasource_config
        options = {
          root_dir: embedding_dir,
          filenames: "embedding",
          append_only: true,
          primary_key: dataset.dataset_primary_key,
          s3_bucket: datasource_config.dig("s3_bucket") || EasyML::Configuration.s3_bucket,
          s3_prefix: s3_prefix,
          polars_args: datasource_config.dig("polars_args"),
        }.compact
        super(options)
      else
        super({ root_dir: "" })
      end
    end

    def cp(old_version, new_version)
      false
    end

    private

    def embedding_dir
      File.join(
        Rails.root,
        "easy_ml/datasets",
        column&.dataset&.name&.parameterize&.gsub("-", "_"),
        "embeddings",
        column&.name&.parameterize&.gsub("-", "_")
      )
    end

    def s3_prefix
      File.join("datasets", embedding_dir.split("datasets").last)
    end
  end
end
