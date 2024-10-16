module EasyML::Data
  class Datasource
    class MergedDatasource < Datasource
      include GlueGun::DSL

      attribute :root_dir, :string
      attribute :polars_args, :hash, default: {}
      attribute :merge
      validates :root_dir, presence: true
      validates :merge, presence: true

      def in_batches(of: 10_000, &block)
        Polars.read_csv(file_path, **polars_args).iter_batches(batch_size: of, &block)
      end

      def file_path
        @file_path ||= File.join(root_dir, "merged_data.csv")
      end

      def last_updated_at
        datasources.map(&:last_updated_at).min
      end

      def refresh!
        cleanup
        if datasources.is_a?(Array)
          datasources.each(&:refresh!)
        elsif datasources.is_a?(Hash)
          datasources.values.each(&:refresh!)
        end
      end

      def data
        @data ||= if file_exists?
                    Polars.read_csv(file_path, **polars_args)
                  else
                    merge_and_save
                  end
      end

      def cleanup
        FileUtils.rm_f(file_path)
      end

      private

      def file_exists?
        File.exist?(file_path)
      end

      def merge_and_save
        refresh!
        merge.call(datasources).tap do |merged_data|
          save_to_file(merged_data)
        end
      end

      def save_to_file(df)
        FileUtils.mkdir_p(root_dir)
        df.write_csv(file_path)
      end
    end
  end
end
