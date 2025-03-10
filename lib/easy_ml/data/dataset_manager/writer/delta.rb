module EasyML
  module Data
    class DatasetManager
      class Writer
        class Delta < Base
          attr_accessor :table, :schema_mode, :optimize_config

          def initialize(options)
            super
            @optimize_config = options.dig(:optimize_config) || {}
            initialize_delta_table
          end

          def store(df, mode: "append")
            ensure_directory_exists

            DeltaLake.write(
              table_uri,
              df,
              mode: mode,
              schema_mode: schema_mode,
            )
          end

          def upsert(df)
            table.merge(df, predicate_for_merge(df))
              .when_matched_update(update_expr_for_merge(df))
              .when_not_matched_insert(insert_expr_for_merge(df))
              .execute
          end

          def delete(predicate)
            table.delete(predicate)
          end

          def refresh_plan
            # Get the latest version information
            current_version = table.version
            
            # Get changes since last processed version
            changes = reader.changes_since(last_processed_version)
            
            {
              changed_rows: changes.filter("_change_type IN ('insert', 'update')"),
              deleted_rows: changes.filter("_change_type = 'delete'"),
              current_version: current_version,
              last_processed_version: last_processed_version
            }
          end

          def merge(source_df, merge_config = {})
            predicate = merge_config[:predicate] || default_merge_predicate
            source_alias = merge_config[:source_alias] || "source"
            target_alias = merge_config[:target_alias] || "target"

            table.merge(
              source_df,
              predicate,
              source_alias: source_alias,
              target_alias: target_alias,
            )
              .when_matched_update(merge_config[:update_expr] || default_update_expr(source_df))
              .when_not_matched_insert(merge_config[:insert_expr] || default_insert_expr(source_df))
              .execute
          end

          def vacuum(retention_hours: 168) # Default 1 week retention
            table.vacuum(
              retention_hours: retention_hours,
              dry_run: false,
              enforce_retention_duration: true,
            )
          end

          def optimize(strategy: :compact, **opts)
            case strategy
            when :compact
              compact_with_options(opts)
            when :z_order
              z_order_with_options(opts)
            else
              raise ArgumentError, "Unknown optimization strategy: #{strategy}"
            end
          end

          def wipe
            FileUtils.rm_rf(root_dir)
            initialize_delta_table
          end

          private

          def compact_with_options(opts = {})
            table.optimize.compact(
              target_size: opts[:target_size] || 128 * 1024 * 1024, # 128MB target
              max_concurrent_tasks: opts[:max_concurrent_tasks],
              min_commit_interval: opts[:min_commit_interval],
            )
          end

          def z_order_with_options(opts = {})
            raise ArgumentError, "z_order requires columns" unless opts[:columns]

            table.optimize.z_order(
              opts[:columns],
              target_size: opts[:target_size],
              max_concurrent_tasks: opts[:max_concurrent_tasks],
              max_spill_size: opts[:max_spill_size] || 20 * 1024 * 1024 * 1024, # 20GB default
            )
          end

          def ensure_directory_exists
            FileUtils.mkdir_p(root_dir) unless Dir.exist?(root_dir)
          end

          def initialize_delta_table
            ensure_directory_exists
            @table = DeltaLake::Table.new(table_uri)
          rescue DeltaLake::TableNotFoundError
            # Table will be created on first write
          end

          def table_uri
            "file://#{root_dir}"
          end

          def default_merge_predicate
            primary_key = options.dig(:primary_key)
            raise ArgumentError, "primary_key required for merge operations" unless primary_key
            "target.#{primary_key} = source.#{primary_key}"
          end

          def default_update_expr(source_df)
            # Update all columns except primary key
            primary_key = options.dig(:primary_key)
            source_df.schema.keys
              .reject { |col| col == primary_key }
              .map { |col| [col, "source.#{col}"] }
              .to_h
          end

          def default_insert_expr(source_df)
            # Insert all columns
            source_df.schema.keys
              .map { |col| [col, "source.#{col}"] }
              .to_h
          end

          def last_processed_version
            # This should be stored/retrieved from your application's state management
            # For now, we'll assume it's stored in a file
            version_file = File.join(dataset_manager.root_dir, ".last_processed_version")
            File.exist?(version_file) ? File.read(version_file).to_i : 0
          end

          def predicate_for_merge(df)
            primary_key = dataset_manager.primary_key
            "target.#{primary_key} = source.#{primary_key}"
          end

          def update_expr_for_merge(df)
            # Create update expressions for all columns except primary key
            df.schema.keys
              .reject { |col| col == dataset_manager.primary_key }
              .map { |col| [col, "source.#{col}"] }
              .to_h
          end

          def insert_expr_for_merge(df)
            # Create insert expressions for all columns
            df.schema.keys
              .map { |col| [col, "source.#{col}"] }
              .to_h
          end

        end
      end
    end
  end
end