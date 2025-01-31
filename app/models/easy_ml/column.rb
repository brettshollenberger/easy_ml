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
#  is_date_column      :boolean          default(FALSE)
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
    after_create :set_date_column_if_date_splitter
    after_save :handle_date_column_change
    before_save :set_defaults

    # Scopes
    scope :visible, -> { where(hidden: false) }
    scope :numeric, -> { where(datatype: %w[float integer]) }
    scope :categorical, -> { where(datatype: %w[categorical string boolean]) }
    scope :datetime, -> { where(datatype: "datetime") }
    scope :date_column, -> { where(is_date_column: true) }

    def columns
      [name].concat(virtual_columns)
    end

    def virtual_columns
      if one_hot?
        allowed_categories.map { |cat| "#{name}_#{cat}" }
      else
        []
      end
    end

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

    def ordinal_encoding?
      preprocessing_steps.deep_symbolize_keys.dig(:training, :params, :ordinal_encoding) == true
    end

    def allowed_categories
      return nil unless one_hot?

      dataset.preprocessor.statistics.dup.to_h.dig(name.to_sym, :allowed_categories).sort.concat(["other"])
    end

    def date_column?
      is_date_column
    end

    private

    def set_defaults
      self.preprocessing_steps = set_preprocessing_steps_defaults
    end

    def set_preprocessing_steps_defaults
      preprocessing_steps.inject({}) do |h, (type, config)|
        h.tap do
          h[type] = set_preprocessing_step_defaults(config)
        end
      end
    end

    ALLOWED_PARAMS = {
      constant: [:constant],
      categorical: %i[categorical_min one_hot ordinal_encoding],
      most_frequent: %i[one_hot ordinal_encoding],
      mean: [:clip],
      median: [:clip],
    }

    REQUIRED_PARAMS = {
      constant: [:constant],
      categorical: %i[categorical_min one_hot ordinal_encoding],
    }

    DEFAULT_PARAMS = {
      categorical_min: 1,
      one_hot: true,
      ordinal_encoding: false,
      clip: { min: 0, max: 1_000_000_000 },
      constant: nil,
    }

    XOR_PARAMS = [{
      params: [:one_hot, :ordinal_encoding],
      default: :one_hot,
    }]

    def set_preprocessing_step_defaults(config)
      config.deep_symbolize_keys!
      config[:params] ||= {}
      params = config[:params].symbolize_keys

      required = REQUIRED_PARAMS.fetch(config[:method].to_sym, [])
      allowed = ALLOWED_PARAMS.fetch(config[:method].to_sym, [])

      missing = required - params.keys
      missing.reject! do |param|
        XOR_PARAMS.any? do |rule|
          if rule[:params].include?(param)
            missing_param = rule[:params].find { |p| p != param }
            params[missing_param] == true
          else
            false
          end
        end
      end
      extra = params.keys - allowed

      missing.each do |key|
        params[key] = DEFAULT_PARAMS.fetch(key)
      end

      extra.each do |key|
        params.delete(key)
      end

      # Only set one of one_hot or ordinal_encoding to true,
      # by default set one_hot to true
      xor = XOR_PARAMS.find { |rule| rule[:params] & params.keys == rule[:params] }
      if xor && xor[:params].all? { |param| params[param] }
        xor[:params].each { |param| params[param] = false }
        params[xor[:default]] = true
      end

      config.merge!(params: params)
    end

    def handle_date_column_change
      return unless saved_change_to_is_date_column? && is_date_column?

      Column.transaction do
        dataset.columns.where.not(id: id).update_all(is_date_column: false)
        dataset.learn_statistics
        dataset.columns.sync
      end
    end

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
