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
#  is_target           :boolean          default(FALSE)
#  hidden              :boolean          default(FALSE)
#  drop_if_null        :boolean          default(FALSE)
#  preprocessing_steps :jsonb
#  sample_values       :json
#  statistics          :json
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#  is_date_column      :boolean          default(FALSE)
#  computed_by         :string
#  is_computed         :boolean          default(FALSE)
#  feature_id          :bigint
#  learned_at          :datetime
#  is_learning         :boolean          default(FALSE)
#  last_datasource_sha :string
#  last_feature_sha    :string
#  in_raw_dataset      :boolean
#
module EasyML
  class Column < ActiveRecord::Base
    self.table_name = "easy_ml_columns"
    include Historiographer::Silent
    historiographer_mode :snapshot_only

    include EasyML::Timing

    belongs_to :dataset, class_name: "EasyML::Dataset"
    belongs_to :feature, class_name: "EasyML::Feature", optional: true
    has_many :lineages, class_name: "EasyML::Lineage"

    validates :name, presence: true
    validates :name, uniqueness: { scope: :dataset_id }

    before_save :ensure_valid_datatype
    after_save :handle_date_column_change
    before_save :set_defaults
    before_save :set_feature_lineage
    before_save :set_polars_datatype
    # after_find :ensure_feature_exists

    # Scopes
    scope :visible, -> { where(hidden: false) }
    scope :numeric, -> { where(datatype: %w[float integer]) }
    scope :categorical, -> { where(datatype: %w[categorical string boolean]) }
    scope :datetime, -> { where(datatype: "datetime") }
    scope :date_column, -> { where(is_date_column: true) }
    scope :not_preprocessed, -> { where("preprocessing_steps IS NULL OR preprocessing_steps::text = '{}'::text") }
    scope :preprocessed, -> { where("preprocessing_steps IS NOT NULL AND preprocessing_steps::text != '{}'::text") }
    scope :required, -> { raw.visible.not_target.not_preprocessed }
    scope :optional, -> { required.not }
    scope :target, -> { where(is_target: true) }
    scope :not_target, -> { where(is_target: false) }
    scope :api_inputs, -> { where(is_computed: false, hidden: false, is_target: false) }
    scope :computed, -> { where(is_computed: true) }
    scope :raw, -> { where(is_computed: false) }
    scope :has_clip, -> { where("preprocessing_steps->'training'->>'params' IS NOT NULL AND preprocessing_steps->'training'->'params' @> jsonb_build_object('clip', jsonb_build_object())") }
    scope :needs_learn, -> {
            datasource_changed
              .or(feature_applied)
              .or(feature_changed)
              .or(column_changed)
              .or(never_learned)
              .or(is_learning)
          }

    scope :datasource_changed, -> {
            left_joins(dataset: :datasource)
              .left_joins(:feature)
              .where(
                arel_table[:last_datasource_sha].not_eq(
                  Datasource.arel_table[:sha]
                )
              )
          }

    scope :feature_changed, -> {
            where(feature_id: Feature.has_changes.map(&:id))
          }

    scope :feature_applied, -> {
            left_joins(dataset: :datasource)
              .left_joins(:feature)
              .where(
                Feature.arel_table[:applied_at].gt(
                  Arel.sql("COALESCE(#{arel_table.name}.learned_at, '1970-01-01')")
                ).and(
                  arel_table[:feature_id].not_eq(nil)
                )
              )
          }

    scope :column_changed, -> {
        left_joins(dataset: :datasource)
          .left_joins(:feature)
          .where(Dataset.arel_table[:refreshed_at].lt(arel_table[:updated_at]))
      }

    scope :never_learned, -> {
            left_joins(dataset: :datasource)
              .left_joins(:feature)
              .where(arel_table[:learned_at].eq(nil))
              .where(Datasource.arel_table[:sha].not_eq(nil))
          }
    scope :is_learning, -> { where(is_learning: true) }

    def ensure_feature_exists
      if feature && !feature.has_code?
        feature.destroy
        update(feature_id: nil)
      end
    end

    def display_attributes
      attributes.except(:statistics)
    end

    def inspect
      "#<#{self.class.name} #{display_attributes.map { |k, v| "#{k}: #{v}" }.join(", ")}>"
    end

    def aliases
      [name].concat(virtual_columns)
    end

    def virtual_columns
      if one_hot?
        allowed_categories.map { |cat| "#{name}_#{cat}" }
      else
        []
      end
    end

    delegate :raw, :processed, :data, :train, :test, :valid, :clipped, to: :data_selector

    def empty?
      data.blank?
    end

    def merge_statistics(new_stats)
      return unless new_stats.present?

      assign_attributes(statistics: (statistics || {}).symbolize_keys.deep_merge!(new_stats))
    end

    def set_configuration_changed_at
      if preprocessing_steps_changed? || datatype_changed?
        self.configuration_changed_at = Time.now
      end
    end

    def set_sample_values
      use_processed = !one_hot? && processed.data(limit: 1).present? && in_raw_dataset?

      base = use_processed ? processed : raw
      sample_values = base.data(limit: 5, unique: true, select: [name])
      if sample_values.columns.include?(name)
        sample_values = sample_values[name].to_a.uniq[0...5]
        assign_attributes(sample_values: sample_values)
      end
    end

    def transform(df, inference: false, computed: false)
      imputer = inference && imputers.inference.anything? ? imputers.inference : imputers.training

      df = imputer.transform(df)
      df
    end

    def imputers(imputers = [])
      @imputers ||= Column::Imputers.new(self, imputers: imputers)
    end

    def decode_labels(df)
      imputers.training.decode_labels(df)
    end

    def preprocessed?
      !preprocessing_steps.blank?
    end

    def datatype=(dtype)
      if dtype.is_a?(Polars::DataType)
        dtype = polars_to_sym(dtype)
      end
      write_attribute(:datatype, dtype)
      set_polars_datatype
    end

    def polars_to_sym(dtype)
      EasyML::Data::PolarsColumn.polars_to_sym(dtype)
    end

    def datatype
      read_attribute(:datatype) || write_attribute(:datatype, polars_to_sym(assumed_datatype))
    end

    def raw_dtype
      dtype = dataset.raw_schema[name]
      return nil if dtype.nil?

      polars_to_sym(dtype)
    end

    def set_polars_datatype
      raw_type = datatype
      user_type = get_polars_type(datatype)

      if raw_type == user_type
        # A raw type of Polars::Datetime might have extra information like timezone, so prefer the raw type
        write_attribute(:polars_datatype, raw_type.to_s)
      else
        # If a user specified type doesn't match the raw type, use the user type
        write_attribute(:polars_datatype, user_type.to_s)
      end
    end

    def polars_datatype
      begin
        raw_attr = read_attribute(:polars_datatype)
        if raw_attr.nil?
          get_polars_type(datatype)
        else
          EasyML::Data::PolarsColumn.parse_polars_dtype(raw_attr)
        end
      rescue => e
        get_polars_type(datatype)
      end
    end

    EasyML::Data::PolarsColumn::TYPE_MAP.keys.each do |dtype|
      define_method("#{dtype}?") do
        datatype.to_s == dtype.to_s
      end
    end

    def datasource_raw
      dataset.datasource.query(select: name)
    end

    def already_computed?
      is_computed && computing_feature&.fit_at.present? || computing_feature&.applied_at.present?
    end

    def assumed_datatype
      return @assumed_datatype if @assumed_datatype

      if in_raw_dataset?
        @assumed_datatype = dataset.raw_schema[name]
        # series = (raw.data || datasource_raw).to_series
        # @assumed_datatype = EasyML::Data::PolarsColumn.determine_type(series)
      elsif dataset.processed_schema.present?
        @assumed_datatype = dataset.processed_schema[name]
      elsif already_computed?
        return nil if processed.data.nil?

        @assumed_datatype = EasyML::Data::PolarsColumn.determine_type(processed.data.to_series)
      end
    end

    def in_raw_dataset?
      value = read_attribute(:in_raw_dataset)
      return value unless value.nil?

      write_attribute(:in_raw_dataset, check_in_raw_dataset?)
    end

    def check_in_raw_dataset?
      return false if dataset&.raw&.data.nil?

      dataset.raw.data(all_columns: true, lazy: true).schema.key?(name) || false
    end

    def computing_feature
      dataset&.features&.detect { |feature| feature.computes_columns.include?(name) }.tap do |computing_feature|
        if computing_feature.present? && feature_id != computing_feature.id
          update(feature_id: computing_feature.id)
        end
      end
    end

    def set_feature_lineage
      return if dataset.nil?

      if dataset.features.computed_column_names.include?(name)
        if computed_by.nil?
          assign_attributes(
            is_computed: true,
            computed_by: computing_feature&.name,
          )
        end
      elsif computed_by.present?
        assign_attributes(
          is_computed: false,
          computed_by: nil,
        )
      end
    end

    def get_polars_type(dtype)
      return nil if dtype.nil?

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
          c[:params][:constant] = cast(c[:params][:constant])
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

    def encoding
      return nil unless categorical?
      return :ordinal if ordinal_encoding?
      return :one_hot
    end

    def categorical_min
      return default_categorical_min unless categorical?

      (preprocessing_steps || {}).deep_symbolize_keys.dig(:training, :params, :categorical_min) || default_categorical_min
    end

    def default_categorical_min
      1
    end

    def statistics
      (read_attribute(:statistics) || {}).with_indifferent_access
    end

    def allowed_categories
      stats = statistics
      return [] if stats.nil? || stats.blank?

      stats = stats.deep_symbolize_keys
      type = is_computed? ? :processed : :raw
      stats = stats.dig(type)

      # Can we LEARN dtype during LEARN phase... for computed columns to deal with this ish man
      sorted = (stats.dig(:allowed_categories) || []).sort_by(&method(:sort_by))
      sorted = sorted.concat(["other"]) if categorical?
      sorted
    end

    def sort_by(value)
      case datatype.to_sym
      when :boolean
        value == true ? 1 : 0
      else
        value
      end
    end

    def date_column?
      is_date_column
    end

    def required?
      !is_computed && (preprocessing_steps.nil? || preprocessing_steps == {}) && !hidden && !is_target
    end

    def sort_required
      required? ? 0 : 1
    end

    def to_api
      {
        name: name,
        datatype: datatype,
        description: description,
        required: required?,
        allowed_values: allowed_categories.empty? ? nil : allowed_categories,
      }.compact
    end

    UNCONFIGURABLE_COLUMNS = %w(
      id
      feature_id
      dataset_id
      last_datasource_sha
      last_feature_sha
      learned_at
      is_learning
      configuration_changed_at
      created_at
      updated_at
    )

    def to_config
      as_json.except(*UNCONFIGURABLE_COLUMNS).with_indifferent_access
    end

    def cast(value)
      return value if value.nil?

      case datatype&.to_sym
      when :float
        value.to_f
      when :integer
        value.to_i
      when :boolean
        ActiveModel::Type::Boolean.new.cast(value)
      when :datetime
        value.is_a?(String) ? Time.parse(value) : value
      when :categorical
        value
      else
        value.to_s
      end
    rescue ArgumentError, TypeError
      # If conversion fails, return original value
      value
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

    NUMERIC_METHODS = %i[mean median].freeze

    def data_selector
      @data_selector ||= Column::Selector.new(self)
    end

    def learner
      @learner ||= Column::Learner.new(self)
    end
  end
end
