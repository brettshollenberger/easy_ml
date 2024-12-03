require "glue_gun"
require_relative "polars_reader"

module EasyML
  module Data
    class SyncedDirectory
      include GlueGun::DSL

      attribute :root_dir, :string
      attribute :s3_bucket, :string
      attribute :s3_prefix, :string
      attribute :s3_access_key_id, :string
      attribute :s3_secret_access_key, :string
      attribute :cache_for, default: nil
      attribute :polars_args, :hash, default: {}

      delegate :query, :data, to: :reader

      def before_sync
        return unless should_sync?

        clean
      end

      def after_sync
        reader.normalize
      end

      def clean
        mk_dir
        clean_dir!
        reader.clean
      end

      def remote_files
        s3.list_objects_v2(bucket: s3_bucket, prefix: s3_prefix)
      end

      def should_sync?(force = false)
        force || !synced?
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
        EasyML::Support::Age.age(last_updated_at, EasyML::Support::EST.now, format: format)
      end

      def stale?
        !synced?
      end

      def synced?
        return @synced unless @synced.nil?

        return true if use_cached?

        @ynced = calculate_synced
      end

      def use_cached?
        return false unless cache_for.present?
        return false if last_updated_at.nil?

        age_in_seconds = EasyML::Support::Age.age(last_updated_at, EasyML::Support::EST.now, format: "integer")
        age_in_seconds < cache_for.to_i
      end

      def last_updated_at
        return nil if files.empty?

        files.map { |file| File.mtime(file) }.max.in_time_zone(EasyML::Support::EST)
      end

      def schema
        reader.schema
      end

      def num_rows
        reader.num_rows
      end

      def download_file(object)
        # Get the relative path by removing s3_prefix from object.key
        local_file_path = File.join(relative_path(root_dir), object.key)
        FileUtils.mkdir_p(File.dirname(local_file_path))

        Rails.logger.info("Downloading object #{object.key} to #{local_file_path}")

        s3.get_object(
          response_target: local_file_path,
          bucket: s3_bucket,
          key: object.key
        )

        Rails.logger.info("Downloaded #{object.key} to #{local_file_path}")
        ungzipped_file_path = ungzip_file(local_file_path)
        Rails.logger.info("Ungzipped to #{ungzipped_file_path}")
      rescue Aws::S3::Errors::ServiceError, Net::OpenTimeout, Net::ReadTimeout, StandardError => e
        Rails.logger.error("Failed to process #{object.key}: #{e.message}")
        raise e
      end

      def upload!(parallel: true)
        upload(force: true, parallel: parallel)
      end

      def upload(force: false, parallel: true)
        files = force ? files_to_upload : files_to_upload.select { |f| should_upload?(f) }
        return true if files.empty?

        if parallel
          Parallel.each(files, in_processes: 4, timeout: 10) { |file| upload_file(file) }
        else
          files.each { |file| upload_file(file) }
        end
        true
      end

      def files_to_upload
        return [] unless Dir.exist?(root_dir)

        local_files = Dir.glob(File.join(root_dir, "**", "*")).select { |f| File.file?(f) }

        # Get remote files and their last modified times
        remote_files = {}
        self.remote_files.contents.each do |object|
          next if object.key.end_with?("/")

          # Remove .gz extension and s3_prefix to match local paths
          local_key = object.key.sub(/\.gz$/, "")
          local_key = local_key.sub(%r{^#{Regexp.escape(s3_prefix)}/}, "") if s3_prefix.present?
          remote_files[local_key] = object.last_modified.in_time_zone(EasyML::Support::EST)
        end

        # Filter files that are newer locally
        local_files.select do |file_path|
          relative_path = Pathname.new(file_path).relative_path_from(Pathname.new(root_dir)).to_s
          local_mtime = File.mtime(file_path).in_time_zone(EasyML::Support::EST)

          # Upload if file doesn't exist remotely or is newer locally
          !remote_files.key?(relative_path) || local_mtime > remote_files[relative_path]
        end
      end

      # Add aliases for sync methods
      alias download! sync!
      alias download sync

      private

      def dir
        s3_prefix.present? ? File.join(relative_path(root_dir), s3_prefix).to_s : root_dir
      end

      def relative_path(path)
        if s3_prefix.present?
          path.sub(Regexp.escape(s3_prefix), "").gsub(%r{/$}, "")
        else
          path
        end
      end

      def reader
        return @reader if @reader

        @reader = EasyML::Data::PolarsReader.new(
          root_dir: dir,
          polars_args: polars_args,
          refresh: false
        )
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

        s3_latest.in_time_zone(EasyML::Support::EST)
      end

      def upload_file(file_path)
        relative_path = Pathname.new(file_path).relative_path_from(Pathname.new(root_dir)).to_s
        s3_key = s3_prefix.present? ? File.join(s3_prefix, relative_path) : relative_path

        # Create a temporary gzipped version of the file
        gzipped_file_path = "#{file_path}.gz"

        begin
          Rails.logger.info("Compressing and uploading #{file_path} to s3://#{s3_bucket}/#{s3_key}")

          # Compress the file
          Zlib::GzipWriter.open(gzipped_file_path) do |gz|
            File.open(file_path, "rb") do |file|
              gz.write(file.read)
            end
          end

          # Upload the gzipped file
          File.open(gzipped_file_path, "rb") do |file|
            s3.put_object(
              bucket: s3_bucket,
              key: "#{s3_key}.gz",
              body: file,
              content_encoding: "gzip"
            )
          end

          Rails.logger.info("Successfully uploaded #{file_path} to s3://#{s3_bucket}/#{s3_key}.gz")
        rescue Aws::S3::Errors::ServiceError, StandardError => e
          Rails.logger.error("Failed to upload #{file_path}: #{e.message}")
          raise e
        ensure
          # Clean up temporary gzipped file
          File.delete(gzipped_file_path) if File.exist?(gzipped_file_path)
        end
      end

      def should_upload?(file_path)
        relative_path = Pathname.new(file_path).relative_path_from(Pathname.new(root_dir)).to_s
        s3_key = s3_prefix.present? ? File.join(s3_prefix, relative_path) : relative_path

        begin
          # Check if file exists in S3
          response = s3.head_object(
            bucket: s3_bucket,
            key: "#{s3_key}.gz"
          )

          # Compare modification times
          local_mtime = File.mtime(file_path).in_time_zone(EasyML::Support::EST)
          remote_mtime = response.last_modified.in_time_zone(EasyML::Support::EST)

          local_mtime > remote_mtime
        rescue Aws::S3::Errors::NotFound
          # File doesn't exist in S3, should upload
          true
        rescue Aws::S3::Errors::ServiceError => e
          Rails.logger.error("Error checking S3 object: #{e.message}")
          raise e
        end
      end
    end
  end
end
