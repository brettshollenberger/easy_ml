module EasyML
  module ColumnList
    def sync(only_new: false)
      return unless dataset.schema.present?

      EasyML::Column.transaction do
        col_names = syncable
        existing_columns = where(name: col_names)
        import_new(col_names, existing_columns)

        if !only_new
          update_existing(existing_columns)
          delete_missing(existing_columns)
        end

        if existing_columns.none? # Totally new dataset
          dataset.after_create_columns
        end
      end
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

    def virtual_column?(column)
      false
    end

    def syncable
      dataset.processed_schema.keys.select do |col|
        !one_hot?(col) &&
          !virtual_column?(col)
      end
    end

    def column_list
      self
    end

    def dataset
      proxy_association.owner
    end

    private

    def import_new(new_columns, existing_columns)
      new_columns = new_columns - existing_columns.map(&:name)
      cols_to_insert = new_columns.map do |col_name|
        EasyML::Column.new(
          name: col_name,
          dataset_id: dataset.id,
        )
      end
      EasyML::Column.import(cols_to_insert)
    end

    def update_existing(existing_columns)
      stats = dataset.statistics
      use_processed = dataset.processed.data(limit: 1).present?
      cached_sample = use_processed ? dataset.processed.data(limit: 10, all_columns: true) : dataset.raw.data(limit: 10, all_columns: true)
      existing_types = existing_columns.map(&:name).zip(existing_columns.map(&:datatype)).to_h
      polars_types = cached_sample.columns.zip((cached_sample.dtypes.map do |dtype|
        EasyML::Data::PolarsColumn.polars_to_sym(dtype).to_s
      end)).to_h

      existing_columns.each do |column|
        new_polars_type = polars_types[column.name]
        existing_type = existing_types[column.name]
        schema_type = dataset.schema[column.name]

        # Keep both datatype and polars_datatype if it's an ordinal encoding case
        if column.ordinal_encoding?
          actual_type = existing_type
          actual_schema_type = existing_type
        else
          actual_type = new_polars_type
          actual_schema_type = schema_type
        end

        if column.one_hot?
          base = dataset.raw
          processed = stats.dig("raw", column.name).dup
          processed["null_count"] = 0
          actual_schema_type = "categorical"
          actual_type = "categorical"
        else
          base = use_processed ? dataset.processed : dataset.raw
          processed = stats.dig("processed", column.name)
        end
        sample_values = base.send(:data, unique: true, limit: 5, all_columns: true, select: column.name)[column.name].to_a.uniq[0...5]

        column.assign_attributes(
          statistics: {
            raw: stats.dig("raw", column.name),
            processed: processed,
          },
          datatype: actual_schema_type,
          polars_datatype: actual_type,
          sample_values: sample_values,
        )
      end
      EasyML::Column.import(existing_columns.to_a,
                            { on_duplicate_key_update: { columns: %i[statistics datatype polars_datatype
                                                                   sample_values] } })
    end

    def delete_missing(existing_columns)
      raw_cols = dataset.raw.train(all_columns: true, limit: 1).columns
      raw_cols = where(name: raw_cols)
      columns_to_delete = column_list - existing_columns - raw_cols
      columns_to_delete.each(&:destroy!)
    end
  end
end
