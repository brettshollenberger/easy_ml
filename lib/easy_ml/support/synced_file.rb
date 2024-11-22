require "glue_gun"

module EasyML
  module Support
    class SyncedFile
      include GlueGun::DSL

      attribute :root_dir, :string
      attribute :filename, :string
      attribute :s3_bucket, :string
      attribute :s3_prefix, :string
      attribute :s3_access_key_id, :string
      attribute :s3_secret_access_key, :string
      attribute :s3_region, :string

      # root_dir + s3_prefix = path
      # path + filename = full_path
      # input_file => "/Users/brettshollenberger/programming/easy_ml/lib/easy_ml/core/models/easy_ml_models/bart/xgboost_20241025120809.json"
      # output_file => "/Users/brettshollenberger/programming/fundera/app/services/bart/standard/easy_ml_models/Bart/xgboost_20241025120809.json"
      #
      def upload(file_path)
        # Ensure the file exists locally before attempting upload
        raise "File #{file_path} does not exist" unless File.exist?(file_path)

        # Calculate the path for the file on S3
        self.filename = Pathname.new(file_path).basename.to_s
        s3_key = s3_prefix.present? ? File.join(s3_prefix, filename) : filename

        # Perform the upload to S3
        s3.put_object(
          bucket: s3_bucket,
          key: s3_key,
          body: File.open(file_path),
        )

        file_path
      end

      def download(full_path)
        base_path = File.join(s3_prefix, filename)
        FileUtils.mkdir_p(File.dirname(full_path))

        s3.get_object(
          response_target: full_path,
          bucket: s3_bucket,
          key: base_path,
        )

        full_path
      end

      def path
        File.join(root_dir, s3_prefix)
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

      def last_updated_at
        return nil if files.empty?

        files.map { |file| File.mtime(file) }.max.in_time_zone(EST)
      end

      private

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
            credentials = Aws::Credentials.new(s3_access_key_id, s3_secret_access_key)
            Aws::S3::Client.new(credentials: credentials)
          end
      end
    end
  end
end
