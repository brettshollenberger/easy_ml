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
  class Datasource < ActiveRecord::Base
    self.table_name = "easy_ml_datasources"
    include Historiographer::Silent
    historiographer_mode :snapshot_only
    include EasyML::Concerns::Configurable

    DATASOURCE_OPTIONS = {
      "s3" => "EasyML::Datasources::S3Datasource",
      "file" => "EasyML::Datasources::FileDatasource",
      "polars" => "EasyML::Datasources::PolarsDatasource"
    }
    DATASOURCE_TYPES = [
      {
        value: "s3",
        label: "Amazon S3",
        description: "Connect to data stored in Amazon Simple Storage Service (S3) buckets"
      },
      {
        value: "file",
        label: "Local Files",
        description: "Connect to data stored in local files"
      },
      {
        value: "polars",
        label: "Polars DataFrame",
        description: "In-memory dataframe storage using Polars"
      }
    ].freeze
    DATASOURCE_NAMES = DATASOURCE_OPTIONS.keys.freeze
    DATASOURCE_CONSTANTS = DATASOURCE_OPTIONS.values.map(&:constantize)

    validates :name, presence: true
    validates :datasource_type, presence: true
    validates :datasource_type, inclusion: { in: DATASOURCE_NAMES }
    validate :validate_datasource_exists

    before_save :set_root_dir
    after_initialize :read_adapter_from_configuration
    after_find :read_adapter_from_configuration
    before_save :store_adapter_in_configuration

    has_many :events, as: :eventable, class_name: "EasyML::Event", dependent: :destroy
    attr_accessor :schema, :columns, :num_rows, :is_syncing

    add_configuration_attributes :schema, :columns, :num_rows, :polars_args, :verbose, :is_syncing
    DATASOURCE_CONSTANTS.flat_map(&:configuration_attributes).each do |attribute|
      add_configuration_attributes attribute
    end

    delegate :query, :in_batches, :files, :all_files, :last_updated_at, :data, :needs_refresh?,
             :refresh, :refresh!, :should_sync?, :files_to_sync, :s3_access_key_id, :s3_secret_access_key,
             :download_file, :clean, to: :adapter

    def self.constants
      {
        DATASOURCE_TYPES: DATASOURCE_TYPES,
        s3: EasyML::Datasources::S3Datasource.constants
      }
    end

    def in_memory?
      datasource_type == "polars"
    end

    def root_dir
      persisted = read_attribute(:root_dir)
      return persisted if persisted.present? && !persisted.to_s.blank?

      default_root_dir
    end

    def refresh_async
      EasyML::SyncDatasourceWorker.perform_async(id)
    end

    def before_sync
      update!(is_syncing: true)
      adapter.before_sync
      Rails.logger.info("Starting sync for datasource #{id}")
    end

    def after_sync
      adapter.after_sync
      self.schema = data.schema.reduce({}) do |h, (k, v)|
        h.tap do
          h[k] = EasyML::Data::PolarsColumn.polars_to_sym(v)
        end
      end
      self.columns = data.columns
      self.num_rows = data.shape[0]
      self.is_syncing = false
      save
    end

    def syncing
      before_sync
      yield.tap do
        after_sync
      end
    end

    def root_dir=(value)
      raise "Cannot override value of root_dir!" unless value.to_s == default_root_dir.to_s

      write_attribute(:root_dir, value)
    end

    private

    def adapter
      @adapter ||= begin
        adapter_class = DATASOURCE_OPTIONS[datasource_type]
        raise "Don't know how to use datasource adapter #{datasource_type}!" unless adapter_class.present?

        adapter_class.constantize.new(self)
      end
    end

    def default_root_dir
      folder = name.gsub(/\s{2,}/, " ").split(" ").join("_").downcase
      EasyML::Engine.root_dir.join("datasources").join(folder)
    end

    def set_root_dir
      write_attribute(:root_dir, default_root_dir) unless read_attribute(:root_dir).present?
    end

    def read_adapter_from_configuration
      return unless persisted?

      adapter.read_from_configuration if adapter.respond_to?(:read_from_configuration)
    end

    def store_adapter_in_configuration
      adapter.store_in_configuration if adapter.respond_to?(:store_in_configuration)
    end

    def validate_datasource_exists
      return if adapter.exists?

      errors.add(:root_dir, adapter.error_not_exists)
    end
  end
end
