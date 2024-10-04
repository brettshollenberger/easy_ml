require "polars"

module EasyML::Data
  class Datasource
    class S3Datasource
      include GlueGun::DSL

      attribute :root_dir, :string
      validates :root_dir, presence: true

      attribute :polars_args, :hash, default: {}
      validates :polars_args, presence: true

      attribute :s3_bucket, :string
      validates :s3_bucket, presence: true

      attribute :s3_prefix, :string
      validates :s3_prefix, presence: true

      attribute :s3_access_key_id, :string
      validates :s3_access_key_id, presence: true

      attribute :s3_secret_access_key, :string
      validates :s3_secret_access_key, presence: true

      dependency :synced_directory do |dependency|
        dependency.set_class EasyML::Support::SyncedDirectory
        dependency.attribute :root_dir, required: true
        dependency.attribute :s3_bucket, required: true
        dependency.attribute :s3_prefix
        dependency.attribute :s3_access_key_id, required: true
        dependency.attribute :s3_secret_access_key, required: true
      end

      delegate :files, :last_updated_at, to: :synced_directory

      def in_batches(of: 10_000)
        # Currently ignores batch size, TODO: implement
        pull
        files.each do |file|
          csv = Polars.read_csv(file, **polars_args)
          yield csv
        end
      end

      def refresh!
        synced_directory.sync
      end

      def data
        pull do |did_sync|
          output_path = File.join(root_dir, "combined_data.csv")

          if did_sync
            combined_df = merge_data
            combined_df.write_csv(output_path)
          else
            Polars.read_csv(output_path, **polars_args)
          end
        end
        combined_df
      end

      private

      def pull
        # Synced directory will only sync if needs sync
        did_sync = synced_directory.sync
        yield did_sync if block_given?
      end

      def merge_data
        combined_df = nil
        files.each do |file|
          df = Polars.read_csv(file, **polars_args)
          combined_df = if combined_df.nil?
                          df
                        else
                          combined_df.vstack(df)
                        end
        end
        combined_df
      end
    end
  end
end
