# == Schema Information
#
# Table name: easy_ml_datasets
#
#  id                 :bigint           not null, primary key
#  name              :string           not null
#  dataset_type      :string
#  status            :string
#  version           :string
#  datasource_id     :bigint
#  root_dir          :string
#  configuration     :json
#  verbose           :boolean          default(FALSE)
#  today             :date
#  target            :string           not null
#  batch_size        :integer          default(50000)
#  drop_if_null      :json             default([])
#  polars_args       :json             default({})
#  transforms        :string
#  drop_cols         :json             default([])
#  preprocessing_steps :json            default({})
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#
require_relative "concerns/statuses"

module EasyML
  class Dataset < ActiveRecord::Base
    include EasyML::Concerns::Statuses
    include EasyML::Logging

    self.filter_attributes += [:configuration]

    validates :name, presence: true
    validates :target, presence: true
    validate :validate_splitter_configuration
    validate :validate_transforms

    belongs_to :datasource,
               foreign_key: :datasource_id,
               class_name: "EasyML::Datasource"

    has_many :models, class_name: "EasyML::Model"

    before_validation :ensure_configuration
    before_save :symbolize_configuration

    attr_accessor :splitter_instance, :preprocessor_instance, :raw_instance, :processed_instance

    delegate :new_data_available?, :synced?, :stale?, to: :datasource
    delegate :splits, to: :splitter
    delegate :statistics, to: :preprocessor

    # Attribute normalizers
    def root_dir=(value)
      super(value ? Pathname.new(value).append("data").to_s : nil)
    end

    def drop_if_null
      super || []
    end

    def polars_args
      (super || {}).deep_symbolize_keys.transform_values do |v|
        k == :dtypes ? v.stringify_keys : v
      end
    end

    def drop_cols
      super || []
    end

    def preprocessing_steps
      super || {}
    end

    def train(**kwargs)
      load_data(:train, **kwargs)
    end

    def valid(**kwargs)
      load_data(:valid, **kwargs)
    end

    def test(**kwargs)
      load_data(:test, **kwargs)
    end

    def data(**kwargs)
      load_data(:all, **kwargs)
    end

    def today=(value)
      super(value&.in_time_zone(UTC)&.to_date)
    end

    def transforms_class
      return nil if transforms.blank?

      @transforms_class ||= transforms.constantize
    end

    # Instance methods
    def splitter
      @splitter_instance ||= Splitter.build(configuration[:splitter] || {})
    end

    def preprocessor
      @preprocessor_instance ||= Preprocessor.new(
        directory: Pathname.new(root_dir).append("preprocessor"),
        preprocessing_steps: preprocessing_steps
      )
    end

    def raw
      @raw_instance ||= build_split(:raw)
    end

    def processed
      @processed_instance ||= build_split(:processed)
    end

    # Process data methods
    def process_data
      split_data
      fit
      normalize_all
      alert_nulls
    end

    def refresh
      refresh_datasource
      return if processed?

      process_data
    end

    def refresh!
      cleanup
      refresh_datasource!
      process_data
    end

    private

    def validate_splitter_configuration
      return unless configuration&.dig(:splitter)

      splitter_config = configuration[:splitter]
      case splitter_config[:type].to_s
      when "date"
        validate_date_splitter(splitter_config)
      end
    end

    def validate_date_splitter(config)
      required_fields = %i[today date_col months_test months_valid]
      missing_fields = required_fields.select { |field| config[field].blank? }

      return unless missing_fields.any?

      errors.add(:configuration, "Missing required fields for date splitter: #{missing_fields.join(", ")}")
    end

    def validate_transforms
      return if transforms.blank?

      unless Object.const_defined?(transforms)
        errors.add(:transforms, "must be a valid class name")
        return
      end

      klass = transforms.constantize
      return if klass.included_modules.include?(EasyML::Transforms)

      errors.add(:transforms, "class must include EasyML::Transforms")
    end

    def ensure_configuration
      self.configuration ||= {}
      self.drop_if_null ||= []
      self.polars_args ||= {}
      self.drop_cols ||= []
      self.preprocessing_steps ||= {}
    end

    def symbolize_configuration
      self.configuration = configuration.deep_symbolize_keys if configuration.present?
      self.polars_args = polars_args.deep_symbolize_keys if polars_args.present?
      self.preprocessing_steps = preprocessing_steps.deep_symbolize_keys if preprocessing_steps.present?
    end

    def build_split(type)
      if datasource.respond_to?(:df)
        InMemorySplit.new(
          polars_args: polars_args,
          batch_size: batch_size,
          verbose: verbose
        )
      else
        FileSplit.new(
          dir: Pathname.new(root_dir).append("files/splits/#{type}"),
          polars_args: polars_args,
          max_rows_per_file: batch_size,
          batch_size: batch_size,
          verbose: verbose
        )
      end
    end

    # ... rest of the private methods from lib/dataset ...
  end
end
