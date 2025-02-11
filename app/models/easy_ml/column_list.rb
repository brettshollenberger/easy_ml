module EasyML
  module ColumnList
    include Historiographer::Relation
    include EasyML::Timing

    def sync(delete: true)
      return unless dataset.schema.present?

      EasyML::Column.transaction do
        col_names = syncable
        existing_columns = where(name: col_names)
        import_new(col_names, existing_columns)
        # update_existing(existing_columns)

        if delete
          delete_missing(col_names)
        end

        if existing_columns.none? # Totally new dataset
          dataset.after_create_columns
        end
      end
    end

    def transform(df, inference: false, computed: false)
      return df if df.nil?

      if computed
        cols = column_list.computed
      else
        cols = column_list.raw
      end

      by_name = cols.index_by(&:name)
      df.columns.each do |col|
        column = by_name[col]
        df = column.transform(df, inference: inference, computed: computed) if column
      end

      df
    end

    def run_queries(queries)
      raw_queries = queries.flat_map do |col|
        col[:raw]
      end
      raw = dataset.raw.data(lazy: true)
      raw.select(raw_queries).collect
    end

    measure_method_timing :run_queries

    def apply_clip(df)
      clip_cols = has_clip.raw
      return df unless clip_cols.any?

      clipped_exprs = EasyML::ColumnList::Imputer.new(
        dataset,
        df,
        columns: clip_cols,
        imputers: [:clip],
      ).exprs

      df.with_columns(clipped_exprs)
    end

    def learn(type: :raw, computed: false)
      EasyML::Dataset::Learner.new(dataset, type: type).learn

      # cols_to_learn = column_list.reload.needs_learn.sort_by(&:name)
      # cols_to_learn = cols_to_learn.computed if computed
      # cols_to_learn = cols_to_learn.select(&:persisted?).reject(&:empty?)
      # raw_column_list = dataset.schema.keys.sort
      # queries = cols_to_learn.map do |col|
      #   col.assign_attributes(in_raw_dataset: raw_column_list.include?(col.name))
      #   col.actually_learn(type: type)
      # end

      # raw_queries = queries.flat_map do |col|
      #   col[:raw]
      # end.compact
      # clipped_queries = queries.flat_map do |col|
      #   col[:clipped]
      # end.compact
      # processed_queries = queries.flat_map do |col|
      #   col[:processed]
      # end.compact

      # raw = dataset.raw.data(lazy: true)
      # raw = raw.select(raw_queries).collect

      # clipped = dataset.clipped.data(lazy: true)
      # clipped = clipped.select(clipped_queries).collect if clipped.present?

      # processed = dataset.processed.data(lazy: true)
      # processed = processed.select(processed_queries).collect if processed.present? && type == :processed

      # binding.pry
      # EasyML::Column.import(cols_to_learn, on_duplicate_key_update: { columns: %i[
      #                                        statistics
      #                                        learned_at
      #                                        sample_values
      #                                        last_datasource_sha
      #                                        is_learning
      #                                        datatype
      #                                        polars_datatype
      #                                      ] })
      # set_feature_lineage(cols_to_learn)
      reload
    end

    def statistics
      stats = { raw: {}, processed: {} }
      select(&:persisted?).inject(stats) do |h, col|
        h.tap do
          h[:raw][col.name] = col.statistics.dig(:raw)
          h[:processed][col.name] = col.statistics.dig(:processed)
        end
      end.with_indifferent_access
    end

    def one_hots
      column_list.select(&:one_hot?)
    end

    def allowed_categories
      one_hots.reduce({}) do |h, col|
        h.tap do
          h[col.name] = col.allowed_categories
        end
      end
    end

    def one_hot?(column)
      one_hots.map(&:name).detect do |one_hot_col|
        column.start_with?(one_hot_col)
      end
    end

    def syncable
      dataset.processed_schema.keys.select do |col|
        !one_hot?(col)
      end
    end

    def column_list
      self
    end

    def dataset
      proxy_association.owner
    end

    def sort_by_required
      column_list.sort_by { |col| [col.sort_required, col.name] }
    end

    def set_feature_lineage(cols_to_learn)
      names = dataset.features.computed_column_names
      columns = where(name: names, computed_by: nil).map do |col|
        col.assign_attributes(
          is_computed: true,
          computed_by: col.computing_feature&.name,
        )
        col
      end
      EasyML::Column.import(columns, on_duplicate_key_update: { columns: %i[ is_computed computed_by ] })

      lineage = cols_to_learn.flat_map do |col|
        EasyML::Lineage.learn(col)
      end.compact
      EasyML::Lineage.import(lineage, on_duplicate_key_update: { columns: %i[ column_id key occurred_at description ] })
    end

    private

    def import_new(new_columns, existing_columns)
      new_columns = new_columns - existing_columns.map(&:name)
      cols_to_insert = new_columns.map do |col_name|
        col = EasyML::Column.new(
          name: col_name,
          dataset_id: dataset.id,
        )
        col
      end
      EasyML::Column.import(cols_to_insert)
      set_feature_lineage(cols_to_insert)
      column_list.reload
    end

    def delete_missing(col_names)
      raw_cols = dataset.best_segment.data(all_columns: true, limit: 1).columns
      raw_cols = where(name: raw_cols)
      columns_to_delete = column_list.select do |col|
        col_names.exclude?(col.name) &&
          one_hots.map(&:name).exclude?(col.name) &&
          raw_cols.map(&:name).exclude?(col.name) &&
          dataset.features.flat_map(&:computes_columns).exclude?(col.name)
      end
      columns_to_delete.each(&:destroy!)
    end
  end
end
