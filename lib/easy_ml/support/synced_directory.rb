require "glue_gun"
require_relative "polars_reader"

module EasyML
  module Support
    class SyncedDirectory
      include GlueGun::DSL

      attribute :root_dir, :string
      attribute :s3_bucket, :string
      attribute :s3_prefix, :string
      attribute :s3_access_key_id, :string
      attribute :s3_secret_access_key, :string
      attribute :cache_for, default: nil
      attribute :polars_args, :hash, default: {}

      def before_sync
        return unless should_sync?(force)

        mk_dir
        clean_dir!
      end

      def should_sync?(force = false)
        force || !synced?
      end

      def after_sync
        normalize
      end

      def sync!(parallel: true)
        sync(force: true, parallel: parallel)
      end

      def sync(force: false, parallel: true)
        return false unless should_sync?(force)

        files = files_to_sync

        if parallel
          Parallel.each(files, in_processes: 4, timeout: 10) { |object| download_file(object) }
        else
          files.each { |object| download_file(object) }
        end
        true
      end

      def files_to_sync
        objects = s3.list_objects_v2(bucket: s3_bucket, prefix: s3_prefix).contents
        objects.reject { |object| object.key.end_with?("/") }
      end

      def in_batches(&block)
        reader.in_batches(&block)
      end

      def files
        reader.files
      end

      def age(format: "human")
        Age.age(last_updated_at, EST.now, format: format)
      end

      def stale?
        !synced?
      end

      def synced?
        return @synced unless @synced.nil?

        return true if use_cached?

        @synced = calculate_synced
      end

      def use_cached?
        return false unless cache_for.present?
        return false if last_updated_at.nil?

        age_in_seconds = EasyML::Support::Age.age(last_updated_at, EST.now, format: "integer")
        age_in_seconds < cache_for.to_i
      end

      def last_updated_at
        return nil if files.empty?

        files.map { |file| File.mtime(file) }.max.in_time_zone(EST)
      end

      def schema
        reader.schema
      end

      def num_rows
        reader.num_rows
      end

      def download_file(object)
        gzipped_file_path = File.join(root_dir, object.key)
        FileUtils.mkdir_p(File.dirname(gzipped_file_path))

        Rails.logger.info("Downloading object #{object.key}")
        s3.get_object(
          response_target: gzipped_file_path,
          bucket: s3_bucket,
          key: object.key
        )

        Rails.logger.info("Downloaded #{object.key} to #{gzipped_file_path}")
        ungzipped_file_path = ungzip_file(gzipped_file_path)
        Rails.logger.info("Ungzipped to #{ungzipped_file_path}")
      rescue Aws::S3::Errors::ServiceError, Net::OpenTimeout, Net::ReadTimeout, StandardError => e
        Rails.logger.error("Failed to process #{object.key}: #{e.message}")
        raise e
      end

      private

      def reader
        return @reader if @reader

        @reader = EasyML::PolarsReader.new(
          root_dir: File.join(root_dir, s3_prefix),
          polars_args: polars_args,
          refresh: false
        )
      end

      def normalize
        reader.normalize
      end

      def mk_dir
        FileUtils.mkdir_p(root_dir)
      end

      def clean_dir!
        unless root_dir.start_with?(Rails.root.to_s)
          raise "Refusing to wipe directory #{root_dir}, as it is not in the scope of #{Rails.root}"
        end

        FileUtils.rm_rf(root_dir)
      end

      def s3
        @s3 ||= begin
          credentials = Aws::Credentials.new(
            s3_access_key_id,
            s3_secret_access_key
          )
          Aws::S3::Client.new(
            credentials: credentials,
            http_open_timeout: 5, # Timeout for establishing connection (in seconds)
            http_read_timeout: 30, # Timeout for reading response (in seconds))
            http_wire_trace: false, # Enable verbose HTTP logging
            http_idle_timeout: 0,
            logger: Logger.new(STDOUT) # Logs to STDOUT; you can also set a file
          )
        end
      end

      def ungzip_file(gzipped_file_path)
        ungzipped_file_path = gzipped_file_path.sub(/\.gz$/, "")

        Zlib::GzipReader.open(gzipped_file_path) do |gz|
          File.open(ungzipped_file_path, "wb") do |file|
            file.write(gz.read)
          end
        end

        File.delete(gzipped_file_path) # Optionally delete the gzipped file after extraction
        ungzipped_file_path
      end

      def expand_dir(dir)
        return dir if dir.to_s[0] == "/"

        Rails.root.join(dir)
      end

      def new_data_available?
        return true if files.empty?

        local_latest = last_updated_at
        s3_latest = s3_last_updated_at

        return false if s3_latest.nil?

        s3_latest > local_latest
      end

      def calculate_synced
        return false if age.nil?

        !new_data_available?
      end

      def s3_last_updated_at
        s3_latest = nil

        s3.list_objects_v2(bucket: s3_bucket, prefix: s3_prefix).contents.each do |object|
          next if object.key.end_with?("/")

          s3_latest = [s3_latest, object.last_modified].compact.max
        end

        s3_latest.in_time_zone(EST)
      end
    end
  end
end
