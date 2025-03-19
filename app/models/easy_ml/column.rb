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
#  is_primary_key      :boolean
#  pca_model_id        :integer
#
module EasyML
  class Column < ActiveRecord::Base
    self.table_name = "easy_ml_columns"
    include Historiographer::Silent
    historiographer_mode :snapshot_only

    include EasyML::Timing

    belongs_to :dataset, class_name: "EasyML::Dataset"
    belongs_to :feature, class_name: "EasyML::Feature", optional: true
    belongs_to :pca_model, class_name: "EasyML::PCAModel", optional: true
    has_many :lineages, class_name: "EasyML::Lineage"

    validates :name, presence: true
    validates :name, uniqueness: { scope: :dataset_id }

    before_save :ensure_valid_datatype
    before_save :ensure_valid_encoding
    after_save :handle_unique_attrs
    before_save :set_defaults
    before_save :set_feature_lineage
    before_save :set_polars_datatype
    before_save :ensure_cast_works
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
              .or(is_view)
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

    scope :is_view, -> { 
      left_joins(dataset: :datasource)
          .left_joins(:feature)
          .where(
            Dataset.arel_table[:view_class].not_eq(nil)
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

    def processed_columns
      has_virtual_columns? ? virtual_columns : [name]
    end

    def aliases
      [name].concat(virtual_columns)
    end

    def has_virtual_columns?
      one_hot? || embedded?
    end

    def virtual_columns
      if one_hot?
        allowed_categories.map { |cat| "#{name}_#{cat}" }
      elsif embedded?
        ["#{name}_embedding"]
      else
        []
      end
    end

    delegate :raw, :processed, :data, :train, :test, :valid, to: :data_selector

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

    def transform(df, inference: false, encode: true)
      imputer = inference && imputers.inference.anything? ? imputers.inference : imputers.training

      imputer.encode = encode
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

    VALID_ENCODINGS = [:one_hot, :ordinal, :embedding].freeze

    def encoding
      preprocessing_steps.deep_symbolize_keys.dig(:training, :encoding)&.to_sym
    end

    def one_hot?
      encoding == :one_hot
    end

    def ordinal_encoding?
      encoding == :ordinal
    end

    def embedded?
      encoding == :embedding
    end

    def encoding_applies?(encoding_type)
      encoding == encoding_type
    end

    def validate_encoding
      return true if encoding.nil?
      return false unless VALID_ENCODINGS.include?(encoding)
      true
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

    def embedding_column
      return nil unless embedded?
      virtual_columns.first
    end

    def embed(df, fit: false)
      return df if df.columns.include?(embedding_column) && df.filter(Polars.col(embedding_column).is_null).empty?
      return df unless name.present?
      return df unless embedded?

      if fit
        pca_model = get_pca_model
        return if pca_model.fit_at.present? && pca_model.fit_at > dataset.datasource.refreshed_at && !pca_model_outdated?
      end

      actually_generate_embeddings(df, fit: fit)

      df = decorate_embeddings(df, compressed: true)
      df
    end

    def store_embeddings(df, compressed: false)
      return unless embedded?

      embedding_store.store(df, compressed: compressed)
    end

    def embedding_config
      return nil unless embedded?
      preprocessing_steps = self.preprocessing_steps.deep_symbolize_keys

      preprocessing_steps.dig(:training, :params).slice(:llm, :preset, :dimensions).merge!(
        column: self.name,
        output_column: "#{self.name}_embedding",
        config: {
          default_options: {
            embeddings_model_name: preprocessing_steps.deep_symbolize_keys.dig(:training, :params, :model),
          },
        },
      )
    end

    def embedding_store
      return nil unless embedded?

      @embedding_store ||= EasyML::EmbeddingStore.new(self)
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
      statistics
      created_at
      updated_at
    )

    def to_config
      EasyML::Export::Column.to_config(self)
    end

    def self.from_config(config, dataset, action: :create)
      EasyML::Import::Column.from_config(config, dataset, action: action)
    end

    def cast_statement(series = nil)
      expected_dtype = polars_datatype
      actual_type = series&.dtype || expected_dtype

      return Polars.col(name).cast(expected_dtype).alias(name) if expected_dtype == actual_type

      if encoding.present?
        encoding_cast = case encoding.to_sym
        when :one_hot
          Polars.col(series.name).cast(Polars::Boolean).alias(series.name)
        when :ordinal
          Polars.col(series.name).cast(Polars::Int64).alias(series.name)
        when :embedding
          Polars.col(series.name).alias(series.name)
        end
        return encoding_cast
      end

      cast_statement = case expected_dtype.to_s
                        when /Polars::List/
                          # we should start tracking polars args so we can know what type of list it is
                          Polars.col(name)
                        when /Polars::Boolean/
                          case actual_type.to_s
                          when /Polars::Boolean/, /Polars::Int/
                            Polars.col(name).cast(expected_dtype)
                          when /Polars::Utf/, /Polars::Categorical/, /Polars::String/
                            Polars.col(name).eq("true").cast(expected_dtype)
                          when /Polars::Null/
                            Polars.col(name)
                          else
                            raise "Unexpected dtype: #{actual_type} for column: #{name}"
                          end
                        else
                          Polars.col(name).cast(expected_dtype, strict: false)
                        end

      cast_statement.alias(name)
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

    def get_pca_model
      pca_model || build_pca_model
    end

    def n_dimensions
      return nil unless embedded?

      preprocessing_steps.deep_symbolize_keys.dig(:training, :params, :dimensions)
    end

    private

    def ensure_cast_works
      begin
        raw.data(cast: { name => polars_datatype })
      rescue => e
        raw_dtype = EasyML::Data::PolarsColumn.polars_to_sym(
          raw.data(cast: false, limit: 1).schema[name]
        )
        errors.add(:datatype, "Can't cast from #{raw_dtype} to #{datatype}")
      end
    end

    def pca_model_outdated?
      return false unless EasyML::Data::Embeddings::Compressor::COMPRESSION_ENABLED

      pca_model = get_pca_model
      return false unless pca_model.persisted?
      return false unless n_dimensions.present?

      pca_model.model.params.dig(:n_components) != n_dimensions
    end

    def needs_embed(df, compressed: false)
      if df.columns.exclude?(name)
        Polars::DataFrame.new
      elsif embedding_store.empty?(compressed: compressed)
        df
      else
        stored_embeddings = embedding_store.query(lazy: true, compressed: compressed)
        df.filter(Polars.col(name).is_null.not_).join(
          stored_embeddings.select(name),
          on: name,
          how: "anti",
        )
      end
    end

    def decorate_embeddings(df, compressed: false)
      if df.columns.include?(embedding_column)
        orig_col_order = df.columns
        df = df.drop(embedding_column) if df.columns.include?(embedding_column)
      else
        orig_col_order = df.columns + [embedding_column]
      end

      df = df.join(
        embedding_store.query(lazy: true, compressed: compressed),
        on: name,
        how: "left",
      ).select(orig_col_order)
      df
    end

    def embed_and_compress(df, fit: false)
      needs_embed = self.needs_embed(df, compressed: false)
      needs_recompress = fit && pca_model_outdated?

      extra_params = {
        df: needs_embed,
        pca_model: fit ? nil : get_pca_model.model,
      }.compact
      generator = EasyML::Data::Embeddings.new(embedding_config.merge!(extra_params))

      if needs_embed.shape[0] > 0
        needs_embed = generator.embed
        store_embeddings(needs_embed, compressed: false)
      end

      # When the PCA model is outdated, we need to re-fit the PCA model and re-compress,
      # but we don't need to re-generate the full embeddings again
      if needs_recompress
        needs_embed = decorate_embeddings(df.clone, compressed: false)
        embedding_store.compressed_store.wipe
      end

      needs_embed = self.needs_embed(df, compressed: true)
      return df if needs_embed.empty?
      if !embedding_store.empty? && (needs_embed.columns.exclude?(embedding_column) || ((needs_embed.shape[0] == 1) && needs_embed.filter(Polars.col(embedding_column).is_null).count == 1))
        needs_embed = decorate_embeddings(needs_embed, compressed: false)
      end

      if needs_embed.columns.include?(embedding_column) &&
        (n_dimensions.present? && needs_embed.shape[1] > 0 &&
         n_dimensions < needs_embed[embedding_column][0].count)
        compressed = generator.compress(needs_embed, fit: fit)
        store_embeddings(compressed, compressed: true)
      else
        store_embeddings(needs_embed, compressed: true)
      end

      if fit
        embedding_store.compact

        get_pca_model.update(
          model: generator.pca_model,
          fit_at: Time.now,
        )
        update(pca_model_id: get_pca_model.id)
      end
    end

    def actually_generate_embeddings(df, fit: false)
      return df if df.empty?

      embed_and_compress(df, fit: fit)
    end

    def set_defaults
      self.preprocessing_steps = set_preprocessing_steps_defaults
    end

    def set_preprocessing_steps_defaults
      preprocessing_steps.deep_symbolize_keys.inject({}) do |h, (type, config)|
        h.tap do
          h[type] = set_preprocessing_step_defaults(config)
        end
      end
    end

    REQUIRED_PARAMS = {
      embedding: %i[llm model],
      constant: [:constant],
      categorical: %i[categorical_min],
    }

    DEFAULT_PARAMS = {
      categorical_min: 1,
      clip: { min: 0, max: 1_000_000_000 },
      constant: nil,
      llm: "openai",
      model: "text-embedding-3-small",
      preset: :full,
    }

    def set_preprocessing_step_defaults(config)
      config.deep_symbolize_keys!
      config[:params] ||= {}
      params = config[:params].deep_symbolize_keys

      required = REQUIRED_PARAMS.fetch(config[:method].to_sym, [])

      missing = required - params.keys
      missing.each do |key|
        params[key] = DEFAULT_PARAMS.fetch(key)
      end

      config.merge!(params: params)
    end

    def handle_unique_attrs
      return unless primary_key_changed? || target_changed? || is_date_column_changed?

      Column.transaction do
        handle_date_column_change
        handle_primary_key_change
        handle_target_change
        resync_dataset if dataset.processed_schema.present? # When using Import, columns are created before the dataset
      end
    end

    def target_changed?
      saved_change_to_is_target? && is_target?
    end

    def primary_key_changed?
      saved_change_to_is_primary_key? && is_primary_key?
    end

    def is_date_column_changed?
      saved_change_to_is_date_column? && is_date_column?
    end

    def handle_target_change
      return unless target_changed?

      dataset.columns.where.not(id: id).update_all(is_target: false)
    end

    def primary_key_changed?
      saved_change_to_is_primary_key? && is_primary_key?
    end

    def handle_primary_key_change
      return unless primary_key_changed?

      dataset.columns.where.not(id: id).update_all(is_primary_key: false)
    end

    def handle_date_column_change
      return unless is_date_column_changed?

      dataset.columns.where.not(id: id).update_all(is_date_column: false)
    end

    def resync_dataset
      dataset.learn_statistics
      dataset.columns.sync
    end

    def ensure_valid_datatype
      return if datatype.blank?

      return if EasyML::Data::PolarsColumn::TYPE_MAP.key?(datatype.to_sym)

      errors.add(:datatype, "must be one of: #{EasyML::Data::PolarsColumn::TYPE_MAP.keys.join(", ")}")
      throw :abort
    end

    def ensure_valid_encoding
      return true if encoding.nil?

      unless VALID_ENCODINGS.include?(encoding)
        errors.add(:encoding, "must be one of: #{VALID_ENCODINGS.join(", ")}")
        throw(:abort)
      end
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
