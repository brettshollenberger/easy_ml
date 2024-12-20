# == Schema Information
#
# Table name: easy_ml_columns
#
#  id                  :bigint           not null, primary key
#  dataset_id          :bigint           not null
#  name                :string           not null
#  description         :string
#  datatype            :string
#  polars_datatype     :string
#  is_target           :boolean
#  hidden              :boolean          default(FALSE)
#  drop_if_null        :boolean          default(FALSE)
#  preprocessing_steps :json
#  sample_values       :json
#  statistics          :json
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#
module EasyML
  class Column < ActiveRecord::Base
    self.table_name = "easy_ml_columns"
    include Historiographer::Silent
    historiographer_mode :snapshot_only

    belongs_to :dataset, class_name: "EasyML::Dataset"

    validates :name, presence: true
    validates :name, uniqueness: { scope: :dataset_id }

    before_save :ensure_valid_datatype

    # Scopes
    scope :visible, -> { where(hidden: false) }
    scope :numeric, -> { where(datatype: %w[float integer]) }
    scope :categorical, -> { where(datatype: %w[categorical string boolean]) }
    scope :datetime, -> { where(datatype: "datetime") }

    def datatype=(dtype)
      write_attribute(:datatype, dtype)
      write_attribute(:polars_datatype, dtype)
    end

    def get_polars_type(dtype)
      EasyML::Data::PolarsColumn::TYPE_MAP[dtype.to_sym]
    end

    def polars_type
      return nil if polars_datatype.blank?

      get_polars_type(polars_datatype)
    end

    def polars_type=(dtype)
      write_attribute(:polars_datatype, dtype.to_s)
      write_attribute(:datatype, EasyML::Data::PolarsColumn::POLARS_MAP[type.class.to_s]&.to_s)
    end

    def preprocessing_steps=(steps)
      return super({}) if steps.blank?

      typed_steps = steps.transform_values do |config|
        next config unless config[:params]&.key?(:constant)

        config.deep_dup.tap do |c|
          c[:params][:constant] = convert_to_type(c[:params][:constant])
        end
      end

      super(typed_steps)
    end

    def preprocessing_steps
      (read_attribute(:preprocessing_steps) || {}).symbolize_keys
    end

    def one_hot?
      preprocessing_steps.deep_symbolize_keys.dig(:training, :params, :one_hot) == true
    end

    private

    def ensure_valid_datatype
      return if datatype.blank?

      return if EasyML::Data::PolarsColumn::TYPE_MAP.key?(datatype.to_sym)

      errors.add(:datatype, "must be one of: #{EasyML::Data::PolarsColumn::TYPE_MAP.keys.join(", ")}")
      throw :abort
    end

    def convert_to_type(value)
      return value if value.nil?

      case datatype&.to_sym
      when :float
        Float(value)
      when :integer
        Integer(value)
      when :boolean
        ActiveModel::Type::Boolean.new.cast(value)
      when :datetime
        value.is_a?(String) ? Time.parse(value) : value
      else
        value.to_s
      end
    rescue ArgumentError, TypeError
      # If conversion fails, return original value
      value
    end

    NUMERIC_METHODS = %i[mean median].freeze
  end
end
