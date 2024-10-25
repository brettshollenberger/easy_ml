require "polars"

module EasyML::Data
  class Datasource
    class S3Datasource
      include GlueGun::DSL

      attribute :verbose, default: false
      attribute :s3_bucket, :string
      attribute :s3_prefix, :string
      attribute :root_dir, :string
      attribute :polars_args, :hash, default: {}

      def polars_args=(args)
        args[:dtypes] = args[:dtypes].stringify_keys if args.key?(:dtypes)
        super(args)
      end

      def s3_prefix=(arg)
        super(arg.to_s.gsub(%r{^/|/$}, ""))
      end

      attribute :s3_access_key_id, :string
      attribute :s3_secret_access_key, :string
      attribute :cache_for

      dependency :synced_directory do |dependency|
        dependency.set_class EasyML::Support::SyncedDirectory
        dependency.bind_attribute :root_dir, required: true
        dependency.bind_attribute :s3_bucket, required: true
        dependency.bind_attribute :s3_prefix
        dependency.bind_attribute :s3_access_key_id, required: true
        dependency.bind_attribute :s3_secret_access_key, required: true
        dependency.bind_attribute :polars_args
        dependency.bind_attribute :cache_for
      end

      delegate :files, :last_updated_at, :in_batches, to: :synced_directory

      def refresh
        synced_directory.sync
      end

      def refresh!
        synced_directory.sync!
      end

      def data
        output_path = File.join(root_dir, "combined_data.csv")
        dfs = []
        unless File.exist?(output_path)
          in_batches do |df|
            dfs.push(df)
          end
          df = Polars.concat(dfs)
          df.write_csv(output_path)
        end
        Polars.read_csv(output_path, **polars_args)
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
