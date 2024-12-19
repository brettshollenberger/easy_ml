module EasyML
  class FeatureStore
    class << self
      def store(feature, df, primary_key: nil)
        path = feature_path(feature)
        FileUtils.mkdir_p(File.dirname(path))

        if File.exist?(path) && primary_key
          reader = EasyML::Data::PolarsReader.new(
            root_dir: File.dirname(path),
          )

          # Use lazy evaluation to efficiently find records to preserve
          preserved_records = reader.query(
            filter: Polars.col(primary_key).is_in(df[primary_key]).is_not,
          )

          # Combine preserved records with new data
          df = Polars.concat([preserved_records, df], how: "vertical")
        end

        df.write_parquet(path)
      end

      def query(feature, filter: nil)
        reader = EasyML::Data::PolarsReader.new
        files = [feature_path(feature)]

        if filter
          reader.query(files, filter: filter)
        else
          reader.query(files)
        end
      end

      private

      def feature_path(feature)
        File.join(
          Rails.root,
          "easy_ml/datasets",
          feature.dataset.name.parameterize,
          "features",
          feature.name.parameterize,
          feature.version.to_s,
          "feature.parquet"
        )
      end
    end
  end
end
