module EasyML
  class Dataset
    class Learner
      include EasyML::Timing
      attr_accessor :dataset, :columns, :all_columns, :type, :computed, :raw_columns, :statistics

      def initialize(dataset, type: :raw)
        @dataset = dataset
        @columns = dataset.columns.reload.needs_learn.includes(:feature).sort_by(&:name)
        @type = type
        @all_columns = @columns.dup
        @columns = @columns.select(&:persisted?)
        @columns = @columns.select { |c| available_columns.include?(c.name) }
      end

      def learn
        prepare
        fit_models
        learn_statistics
        save_statistics
      end

      def available_columns
        @available_columns ||= dataset.send(type).data(lazy: true).schema.keys & columns.map(&:name)
      end

      private

      def fit_models
        fit_embedding_models
      end

      def fit_embedding_models
        columns.select(&:embedded?).each do |col|
          col.embed(dataset.train(all_columns: true), fit: true)
        end
      end

      def get_sample_values
        needs_sample = EasyML::Column.where(id: columns.map(&:id)).where(sample_values: nil).map(&:name)
        sampleable_cols = available_columns & needs_sample
        selects = sampleable_cols.map do |col|
          Polars.col(col).filter(Polars.col(col).is_not_null).limit(5).alias(col)
        end
        df = dataset.send(type).train(all_columns: true, lazy: true).select(selects).collect.to_h.transform_values(&:to_a)
      end

      def save_statistics
        samples = get_sample_values
        all_columns.each do |col|
          col.merge_statistics(statistics.dig(col.name))
          col.assign_attributes(sample_values: samples[col.name]) if samples[col.name].present?
          col.assign_attributes(
            learned_at: EasyML::Support::UTC.now,
            last_datasource_sha: col.dataset.last_datasource_sha,
            last_feature_sha: col.feature&.sha,
            is_learning: type == :raw,
          )
        end

        EasyML::Column.import(all_columns, on_duplicate_key_update: { columns: %i[
                                         statistics
                                         learned_at
                                         sample_values
                                         last_datasource_sha
                                         is_learning
                                       ] })
        dataset.columns.set_feature_lineage(columns)
      end

      def learn_statistics
        return @statistics if @statistics

        @statistics = lazy_statistics.deep_merge!(eager_statistics).reduce({}) do |h, (type, stat_group)|
          h.tap do
            stat_group.each do |statistic, value|
              h[statistic] ||= {}
              h[statistic][type] = value
            end
          end
        end.with_indifferent_access

        if type != :raw
          columns.select(&:one_hot?).each do |column|
            @statistics[column.name][:processed] = @statistics[column.name][:raw]
          end
        end
      end

      def prepare
        @schema = EasyML::Data::PolarsSchema.simplify(@dataset.raw_schema).symbolize_keys
        @raw_columns = @schema.keys.sort.map(&:to_s)
        columns.each do |column|
          attrs = {
            in_raw_dataset: @raw_columns.include?(column.name),
            datatype: column.read_attribute(:datatype).present? ? nil : @schema[column.name.to_sym],
          }.compact
          column.assign_attributes(attrs)
        end
        EasyML::Column.import(columns, on_duplicate_key_update: { columns: %i[in_raw_dataset datatype] })
      end

      def lazy_statistics
        Lazy.new(dataset, columns, type: type).learn
      end

      def eager_statistics
        Eager.new(dataset, columns, type: type).learn
      end
    end
  end
end
