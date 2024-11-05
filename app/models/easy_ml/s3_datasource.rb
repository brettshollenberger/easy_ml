# == Schema Information
#
# Table name: easy_ml_datasources
#
#  id              :bigint           not null, primary key
#  name            :string           not null
#  datasource_type :string
#  root_dir        :string
#  configuration   :json
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#
module EasyML
  class S3Datasource < Datasource
    REGIONS = [
      { value: "us-east-1", label: "US East (N. Virginia)" },
      { value: "us-east-2", label: "US East (Ohio)" },
      { value: "us-west-1", label: "US West (N. California)" },
      { value: "us-west-2", label: "US West (Oregon)" }
    ].freeze

    def self.constants
      { S3_REGIONS: REGIONS }
    end

    attr_accessor :s3_bucket, :s3_prefix, :s3_access_key_id,
                  :s3_secret_access_key, :s3_region, :cache_for, :polars_args,
                  :verbose, :is_syncing, :schema, :columns

    after_initialize :read_from_configuration
    before_save :store_in_configuration

    validates :s3_bucket, :s3_access_key_id, :s3_secret_access_key, presence: true

    def s3_prefix=(value)
      @s3_prefix = value.to_s.gsub(%r{^/|/$}, "")
    end

    def polars_args=(args)
      args[:dtypes] = args[:dtypes].stringify_keys if args&.key?(:dtypes)
      @polars_args = args
    end

    def files
      synced_directory.files
    end

    def last_updated_at
      synced_directory.last_updated_at
    end

    def in_batches(&block)
      synced_directory.in_batches(&block)
    end

    def refresh
      syncing do
        synced_directory.sync
      end
    end

    def refresh!
      syncing do
        synced_directory.sync!
      end
    end

    def syncing
      update(is_syncing: true)
      result = yield
      self.schema = synced_directory.schema
      self.columns = schema.keys
      update(is_syncing: false)
      store_in_configuration
      result
    end

    def data
      dfs = []
      in_batches do |df|
        dfs.push(df)
      end
      Polars.concat(dfs)
    end

    def s3_access_key_id
      EasyML::Configuration.s3_access_key_id
    end

    def s3_secret_access_key
      EasyML::Configuration.s3_secret_access_key
    end

    private

    def synced_directory
      @synced_directory ||= EasyML::Support::SyncedDirectory.new(
        root_dir: root_dir,
        s3_bucket: s3_bucket,
        s3_prefix: s3_prefix,
        s3_access_key_id: s3_access_key_id,
        s3_secret_access_key: s3_secret_access_key,
        polars_args: polars_args,
        cache_for: cache_for
      )
    end

    def store_in_configuration
      super(:s3_bucket, :s3_prefix, :s3_region, :cache_for, :polars_args, :verbose, :is_syncing, :schema, :columns)
    end

    def read_from_configuration
      super(:s3_bucket, :s3_prefix, :s3_region, :cache_for, :polars_args, :verbose, :is_syncing, :schema, :columns)
    end
  end
end
