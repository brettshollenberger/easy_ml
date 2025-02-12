module EasyML
  class Dataset
    class Learner
      include EasyML::Timing
      attr_accessor :dataset, :columns, :type, :computed, :raw_columns, :statistics

      def initialize(dataset, type: :raw)
        @dataset = dataset
        @columns = dataset.columns.reload.needs_learn.sort_by(&:name)

        if computed
          @columns = @columns.computed
        end

        @columns = @columns.select(&:persisted?).reject(&:empty?)
        @type = type
      end

      def learn
        prepare
        learn_statistics
        save_statistics
      end

      private

      def save_statistics
        columns.each do |col|
          col.merge_statistics(statistics.dig(col.name))
          col.set_sample_values
          col.assign_attributes(
            learned_at: EasyML::Support::UTC.now,
            last_datasource_sha: col.dataset.last_datasource_sha,
            last_feature_sha: col.feature&.sha,
            is_learning: type == :raw,
          )
        end

        EasyML::Column.import(columns, on_duplicate_key_update: { columns: %i[
                                         statistics
                                         learned_at
                                         sample_values
                                         last_datasource_sha
                                         is_learning
                                       ] })
        dataset.columns.set_feature_lineage(columns)
      end

      measure_method_timing :save_statistics

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

      measure_method_timing :learn_statistics

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

      measure_method_timing :prepare

      def lazy_statistics
        Lazy.new(dataset, columns, type: type).learn
      end

      measure_method_timing :lazy_statistics

      def eager_statistics
        Eager.new(dataset, columns, type: type).learn
      end

      measure_method_timing :eager_statistics
    end
  end
end
