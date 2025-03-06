require "aws-sdk-s3"

module EasyML
  module Support
    class SyncedFile
      attr_accessor :root_dir, :filename, :s3_bucket, :s3_prefix,
                    :s3_access_key_id, :s3_secret_access_key, :s3_region

      def initialize(options = {})
        @root_dir = options[:root_dir]
        @filename = options[:filename]
        @s3_bucket = options[:s3_bucket] || EasyML::Configuration.s3_bucket
        @s3_prefix = options[:s3_prefix]
        @s3_access_key_id = options[:s3_access_key_id] || EasyML::Configuration.s3_access_key_id
        @s3_secret_access_key = options[:s3_secret_access_key] || EasyML::Configuration.s3_secret_access_key
        @s3_region = options[:s3_region] || EasyML::Configuration.s3_region
      end

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

      def s3_key
        s3_prefix.present? ? File.join(s3_prefix, filename) : filename
      end

      def path
        File.join(root_dir, s3_prefix)
      end

      def age(format: "human")
        Age.age(last_updated_at, EasyML::Support::EST.now, format: format)
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

        files.map { |file| File.mtime(file) }.max.in_time_zone(EasyML::Support::EST)
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
            Aws::S3::Client.new(credentials: credentials, region: s3_region)
          end
      end
    end
  end
end
