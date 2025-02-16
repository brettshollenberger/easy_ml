module EasyML
  module Data
    class DatasetManager
      require_relative "dataset_manager/writer"
      require_relative "dataset_manager/reader"

      attr_accessor :root_dir, :partition, :append_only, :filenames, :primary_key,
                    :partition_size, :s3_bucket, :s3_prefix, :s3_access_key_id,
                    :s3_secret_access_key, :polars_args, :source_of_truth,
                    :options

      def initialize(options = {})
        @root_dir = options.dig(:root_dir)
        @partition = options.dig(:partition) || (options.dig(:partition_size).present? && options.dig(:primary_key).present?)
        @append_only = options.dig(:append_only) || false
        @filenames = options.dig(:filenames) || "file"
        @primary_key = options.dig(:primary_key)
        @partition_size = options.dig(:partition_size) || nil
        @s3_bucket = options.dig(:s3_bucket) || EasyML::Configuration.s3_bucket
        @s3_prefix = options.dig(:s3_prefix) || nil
        @s3_access_key_id = options.dig(:s3_access_key_id) || EasyML::Configuration.s3_access_key_id
        @s3_secret_access_key = options.dig(:s3_secret_access_key) || EasyML::Configuration.s3_secret_access_key
        @polars_args = options.dig(:polars_args) || {}
        @source_of_truth = options.dig(:source_of_truth) || :local
        @options = options

        raise "primary_key required: how should we divide partitions?" if partition && primary_key.nil?
        raise "partition_size required: specify number of rows in each partition" if partition && partition_size.nil?
        raise "root_dir required: specify the root_dir of the dataset" unless root_dir.present?
      end

      def inspect
        keys = %w(root append_only partition primary_key)
        attrs = keys.map { |k| "#{k}=#{send(k)}" unless send(k).nil? }.compact
        "#<#{self.class.name} #{attrs.join("\n\t")}>"
      end

      class << self
        def query(input = nil, **kwargs, &block)
          Reader.query(input, **kwargs, &block)
        end

        def schema(input = nil, **kwargs, &block)
          Reader.schema(input, **kwargs, &block)
        end

        def num_rows
          Reader.num_rows
        end
      end

      def num_rows
        Reader.num_rows(root_dir)
      end

      def query(input = nil, **kwargs, &block)
        input = root_dir if input.nil?
        DatasetManager.query(input, **kwargs, &block)
      end

      def schema(input = nil, **kwargs, &block)
        input = root_dir if input.nil?
        DatasetManager.schema(input, **kwargs, &block)
      end

      def sha
        Reader.sha(root_dir)
      end

      def normalize
        Normalizer.normalize(root_dir)
      end

      def data
        query
      end

      def store(df, *args)
        writer.store(df, *args)
      end

      def compact
        writer.compact
      end

      def cp(from, to)
        writer.cp(from, to)
      end

      def empty?
        files.empty? || query(limit: 1).empty?
      end

      def files
        Reader.files(root_dir)
      end

      def wipe
        writer.wipe
      end

      def upload
        synced_directory.upload
      end

      def download
        synced_directory.download
      end

      private

      def root
        root_dir.gsub(/^#{Rails.root.to_s}/, "")
      end

      def writer
        Writer.new(options)
      end

      def synced_directory
        @synced_dir ||= EasyML::Data::SyncedDirectory.new(
          root_dir: root_dir,
          source_of_truth: source_of_truth,
          s3_bucket: s3_bucket,
          s3_prefix: s3_prefix,
          s3_access_key_id: s3_access_key_id,
          s3_secret_access_key: s3_secret_access_key,
          polars_args: polars_args,
          cache_for: 0,
        )
      end
    end
  end
end
