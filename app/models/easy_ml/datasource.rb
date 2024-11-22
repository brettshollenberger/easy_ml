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
    self.inheritance_column = :datasource_type
    self.table_name = "easy_ml_datasources"
    include Historiographer::Silent
    historiographer_mode :snapshot_only

    include EasyML::Concerns::Configurable

    scope :s3, -> { where(datasource_type: "S3Datasource") }

    DATASOURCE_TYPES = [
      {
        value: "EasyML::S3Datasource",
        label: "Amazon S3",
        description: "Connect to data stored in Amazon Simple Storage Service (S3) buckets",
      },
    ].freeze

    TYPE_CLASSES = %w(
      EasyML::PolarsDatasource
      EasyML::FileDatasource
      EasyML::S3Datasource
    )
    self.inheritance_column = :datasource_type

    validates :name, presence: true
    validates :datasource_type, presence: true
    validates :datasource_type, inclusion: { in: TYPE_CLASSES }

    after_initialize :set_default_root_dir
    has_many :events, as: :eventable, class_name: "EasyML::Event", dependent: :destroy
    attr_accessor :schema, :columns, :num_rows, :is_syncing

    add_configuration_attributes :schema, :columns, :num_rows, :polars_args, :verbose, :is_syncing

    def self.constants
      {
        DATASOURCE_TYPES: DATASOURCE_TYPES,
        s3: EasyML::S3Datasource.constants,
      }
    end

    def in_memory?
      datasource_type == "EasyML::PolarsDatasource"
    end

    def root_dir
      persisted = read_attribute(:root_dir)
      return persisted if persisted.present? && !persisted.to_s.blank?

      default_root_dir
    end

    def default_root_dir
      folder = name.gsub(/\s{2,}/, " ").split(" ").join("_").downcase
      Rails.root.join("easy_ml/datasets").join(folder)
    end

    # Common interface methods
    def in_batches(of: 10_000)
      raise NotImplementedError, "#{self.class} must implement #in_batches"
    end

    def files
      raise NotImplementedError, "#{self.class} must implement #files"
    end

    def last_updated_at
      raise NotImplementedError, "#{self.class} must implement #last_updated_at"
    end

    def data
      raise NotImplementedError, "#{self.class} must implement #data"
    end

    def refresh_async
      EasyML::SyncDatasourceWorker.perform_async(id)
    end

    def before_sync
      update!(is_syncing: true)
      Rails.logger.info("Starting sync for datasource #{id}")
    end

    def after_sync
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

    def set_default_root_dir
      self.root_dir ||= default_root_dir
    end

    delegate :s3_bucket, :s3_prefix, :s3_region, to: :configuration, allow_nil: true
  end
end
