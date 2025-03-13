module EasyML
  module Data
    class DatasetManager
      class Schema
        class Normalizer

          attr_accessor :files

          def initialize(files)
            @files = files
          end

          def normalize
            shared_schema = find_common_schema(files)
            if schema_changed?(files, shared_schema)
              queries = schema_to_queries(shared_schema)
              rewrite_dataset(files, queries)
            end

            queries = improve_schema(files, shared_schema)
            if queries.any?
              rewrite_dataset(files, queries)
            end
            files
          end

        private

          def schema_changed?(files, schema)
            Polars.scan_parquet(files.first).schema != schema
          end

          def rewrite_dataset(files, queries)
            files.each do |file|
              Polars.scan_parquet(file).select(queries).collect.write_parquet("#{file}_normalized.parquet")
              puts "Rewriting #{file}..."
              File.delete(file)
              FileUtils.mv("#{file}_normalized.parquet", file)
            end
          end

          def improve_schema(files, schema)
            checks = schema_checks(schema)
            return [] unless checks.any?

            improvements = Polars.scan_parquet(files).select(checks).collect
            conversions = improvements.to_hashes&.first || []
            return [] unless conversions.any?
            conversions = conversions&.select { |k,v| v }
            return [] unless conversions.any?
            
            conversions = conversions.reduce({}) do |hash, (k, _)|
              hash.tap do
                key, ruby_type = k.split("convert_").last.split("_to_")
                conversion = case ruby_type
                            when "int"
                              Polars.col(key).cast(Polars::Int64).alias(key)
                            else
                              EasyML::Data::DateConverter.conversion(k)
                            end
                hash[key] = conversion
              end
            end
            schema.map do |k, v|
              conversions[k] || Polars.col(k).cast(v).alias(k)
            end
          end

          def schema_to_queries(schema)
            schema.map do |k, v|
              Polars.col(k).cast(v).alias(k)
            end
          end

          def schema_checks(schema)
            schema.flat_map do |key, value|
              case value
              when Polars::FloatType, Polars::Decimal
                Polars.col(key).cast(Polars::Int64).cast(value).eq(Polars.col(key)).all().alias("convert_#{key}_to_int")
              when Polars::String
                EasyML::Data::DateConverter.queries(key)
              end
            end.compact
          end

          # Function to find a common schema across multiple parquet files
          def find_common_schema(parquet_files)
            # Get schema from each file
            schemas = []
            
            parquet_files.each do |file|
              begin
                # Read just the schema without loading data
                schema = Polars.scan_parquet(file).schema
                schemas << schema
              rescue => e
                puts "Warning: Error reading schema from #{file}: #{e.message}"
              end
            end
            
            # Find common schema - start with first file's schema
            return {} if schemas.empty?
            
            key_count = Hash.new(0)
            common_schema = schemas.first
            
            # Reconcile types across all schemas
            schemas.each do |schema|
              schema.each do |name, dtype|
                key_count[name] += 1
                if common_schema.key?(name)
                  # If types don't match, choose the more general type
                  if common_schema[name] != dtype
                    common_schema[name] = choose_compatible_type(common_schema[name], dtype)
                  end
                end
              end
            end
            
            # Filter out columns that aren't present in all files
            common_schema = common_schema.select { |name, _| key_count[name] == schemas.length }
            
            return common_schema
          end

          # Choose a type that's compatible with both input types
          def choose_compatible_type(type1, type2)
            # Integer types - use the larger of the two
            int_types = [Polars::Int8, Polars::Int16, Polars::Int32, Polars::Int64]
            
            # If both are integers, choose the larger one
            if int_types.include?(type1.class) && int_types.include?(type2.class)
              return [type1, type2].max_by { |t| int_types.index(t.class) }
            end
            
            # If one is Int64 and one is Decimal with scale 0, use Decimal
            if (type1.is_a?(Polars::Int64) && type2.is_a?(Polars::Decimal) && type2.scale == 0) ||
              (type2.is_a?(Polars::Int64) && type1.is_a?(Polars::Decimal) && type1.scale == 0)
              return type1.is_a?(Polars::Decimal) ? type1 : type2
            end
            
            # If types are drastically different, convert to string as a safe fallback
            if [Polars::String, Polars::Categorical].include?(type1.class) || 
              [Polars::String, Polars::Categorical].include?(type2.class)
              return Polars::String.new
            end
            
            # For float vs decimal, choose decimal if it has scale > 0
            if (type1.is_a?(Polars::Float64) && type2.is_a?(Polars::Decimal) && type2.scale > 0) ||
              (type2.is_a?(Polars::Float64) && type1.is_a?(Polars::Decimal) && type1.scale > 0)
              return type1.is_a?(Polars::Decimal) ? type1 : type2
            end
            
            # Default to Float64 for numeric type conflicts
            if [Polars::Float32, Polars::Float64, Polars::Decimal, Polars::Int64].any? { |t| type1.is_a?(t) } && 
              [Polars::Float32, Polars::Float64, Polars::Decimal, Polars::Int64].any? { |t| type2.is_a?(t) }
              return Polars::Float64.new
            end
            
            # Fallback - use first type
            return type1
          end

          # Apply a common schema to read all parquet files
          def read_with_common_schema(parquet_files)
            schema = find_common_schema(parquet_files)
            return Polars.scan_parquet(parquet_files).with_schema(schema).collect
          end

          # Alternative approach using a union scan
          def union_scan_parquet(parquet_files)
            if parquet_files.empty?
              return Polars.DataFrame.new
            end
            
            # Create separate scans with explicit schemas
            scans = []
            schema = find_common_schema(parquet_files)
            
            parquet_files.each do |file|
              scans << Polars.scan_parquet(file).with_schema(schema)
            end
            
            # Union all scans
            if scans.length == 1
              return scans.first.collect
            else
              # Combine using concat (union all)
              union = scans.first
              scans[1..-1].each do |scan|
                union = union.concat(scan)
              end
              
              return union.collect
            end
          end
        end
      end
    end
  end
end