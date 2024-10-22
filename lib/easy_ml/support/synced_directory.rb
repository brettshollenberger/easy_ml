require "glue_gun"

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

      def sync!
        sync(force: true)
      end

      def sync(force: false)
        return false if synced? && !force

        mk_dir
        clean_dir!
        download
        true
      end

      def files
        Dir.glob(File.join(root_dir, File.join(s3_prefix, "*.csv")))
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

        age_in_seconds = EasyML::Support::Age.age(last_updated_at, EST.now, format: "integer")
        age_in_seconds < cache_for.to_i
      end

      def last_updated_at
        return nil if files.empty?

        files.map { |file| File.mtime(file) }.max.in_time_zone(EST)
      end

      private

      def mk_dir
        FileUtils.mkdir_p(root_dir)
      end

      def clean_dir!
        # FileUtils.rm_rf(root_dir)
      end

      def s3
        @s3 ||= begin
          credentials = Aws::Credentials.new(s3_access_key_id, s3_secret_access_key)
          Aws::S3::Client.new(credentials: credentials)
        end
      end

      def download
        s3.list_objects_v2(bucket: s3_bucket, prefix: s3_prefix).contents.each do |object|
          next if object.key.end_with?("/") # skip folders

          gzipped_file_path = File.join(root_dir, object.key)
          FileUtils.mkdir_p(File.dirname(gzipped_file_path))

          s3.get_object(
            response_target: gzipped_file_path,
            bucket: s3_bucket,
            key: object.key
          )

          puts "Downloaded #{object.key} to #{gzipped_file_path}"

          # Ungzip the file
          ungzipped_file_path = ungzip_file(gzipped_file_path)
          puts "Ungzipped to #{ungzipped_file_path}"
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
