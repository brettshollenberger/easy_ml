module EasyML
  module Data
    class Embeddings
      class Compressor
        # Quality presets with their respective variance preservation targets
        PRESETS = {
          full: {
            variance_target: 1.0,
            description: "Preserves all information while reducing dimensions",
          },
          high_quality: {
            variance_target: 0.95,
            description: "Preserves 95% of information while reducing dimensions",
          },
          balanced: {
            variance_target: 0.85,
            description: "Balanced approach: 85% information preservation with substantial size reduction",
          },
          space_efficient: {
            variance_target: 0.75,
            description: "Maximizes storage savings while maintaining 75% of important information",
          },
        }

        attr_reader :original_dimensions, :reduced_dimensions, :preserved_variance
        attr_reader :compression_ratio, :storage_savings, :preset_used

        def initialize(config = {})
          @preset = config.dig(:preset)
          @dimensions = config.dig(:dimensions)

          unless @preset || @dimensions
            @preset = :full
          end
          @reducer = nil
          @original_dimensions = nil
          @reduced_dimensions = nil
          @preserved_variance = nil
          @compression_ratio = nil
          @storage_savings = nil
          @preset_used = nil
        end

        def inspect
          "#<#{self.class.name} original_dimensions=#{@original_dimensions}, reduced_dimensions=#{@reduced_dimensions}, preserved_variance=#{@preserved_variance}, compression_ratio=#{@compression_ratio}, storage_savings=#{@storage_savings}, preset_used=#{@preset_used}>"
        end

        # Reduce dimensions using a preset quality level
        def reduce_with_preset(embeddings_df, preset: :balanced)
          unless PRESETS.key?(preset)
            raise ArgumentError, "Unknown preset: #{preset}. Available presets: #{PRESETS.keys.join(", ")}"
          end

          @preset_used = preset
          target_variance = PRESETS[preset][:variance_target]

          reduce_to_variance(embeddings_df, target_variance: target_variance)
        end

        # Reduce dimensions to a specific number
        def reduce_to_dimensions(embeddings_df, target_dimensions:)
          validate_input(embeddings_df)

          embedding_columns = get_embedding_columns(embeddings_df)
          @original_dimensions = embedding_columns.length

          if target_dimensions >= @original_dimensions
            return embeddings_df.clone()
          end

          # Convert embedding columns to Numo::NArray for Rumale
          x = df_to_narray(embeddings_df, embedding_columns)

          # Initialize and fit PCA
          @reducer = Rumale::Decomposition::PCA.new(n_components: target_dimensions)
          transformed = @reducer.fit_transform(x)

          # Calculate variance explained
          @preserved_variance = @reducer.explained_variance_ratio.sum
          @reduced_dimensions = target_dimensions
          @compression_ratio = @original_dimensions.to_f / @reduced_dimensions
          @storage_savings = 1.0 - (1.0 / @compression_ratio)

          # Create new dataframe with reduced embeddings
          result_df = create_result_dataframe(embeddings_df, embedding_columns, transformed)

          result_df
        end

        # Reduce dimensions to preserve a target variance
        def reduce_to_variance(embeddings_df, target_variance:)
          validate_input(embeddings_df)

          embedding_columns = get_embedding_columns(embeddings_df)
          @original_dimensions = embedding_columns.length

          # Convert embedding columns to Numo::NArray for Rumale
          x = df_to_narray(embeddings_df, embedding_columns)

          # First fit PCA with all components to analyze variance
          temp_pca = Rumale::Decomposition::PCA.new(n_components: @original_dimensions)
          temp_pca.fit(x)

          # Find number of components needed for target variance
          cumulative_variance = Numo::NArray.cast(temp_pca.explained_variance_ratio).cumsum
          n_components = (cumulative_variance >= target_variance).where[0]
          n_components = n_components.nil? ? @original_dimensions : n_components + 1

          # Apply PCA with determined number of components
          @reducer = Rumale::Decomposition::PCA.new(n_components: n_components)
          transformed = @reducer.fit_transform(x)

          @preserved_variance = @reducer.explained_variance_ratio.sum
          @reduced_dimensions = n_components
          @compression_ratio = @original_dimensions.to_f / @reduced_dimensions
          @storage_savings = 1.0 - (1.0 / @compression_ratio)

          # Create new dataframe with reduced embeddings
          result_df = create_result_dataframe(embeddings_df, embedding_columns, transformed)

          result_df
        end

        # Get user-friendly stats about the reduction
        def reduction_stats
          return nil unless @reducer

          {
            original_dimensions: @original_dimensions,
            reduced_dimensions: @reduced_dimensions,
            preserved_information: "#{(@preserved_variance * 100).round(1)}%",
            compression_ratio: "#{@compression_ratio.round(1)}x",
            storage_savings: "#{(@storage_savings * 100).round(1)}%",
            preset_used: @preset_used,
            preset_description: @preset_used ? PRESETS[@preset_used][:description] : nil,
          }
        end

        # Generate a human-readable summary of the reduction
        def summary
          stats = reduction_stats
          return "No reduction performed yet" unless stats

          <<~SUMMARY
            Embedding Reduction Summary:
            ----------------------------
            
            #{stats[:preset_used] ? "Quality Preset: #{stats[:preset_used].to_s.gsub("_", " ").capitalize}" : "Custom Reduction"}
            #{stats[:preset_description] ? "\n#{stats[:preset_description]}\n" : ""}
            
            • Original embeddings: #{stats[:original_dimensions]} dimensions
            • Reduced embeddings: #{stats[:reduced_dimensions]} dimensions
            • Information preserved: #{stats[:preserved_information]}
            • Size reduction: #{stats[:compression_ratio]} (#{stats[:storage_savings]} saved)
            
            This means your dataset is now #{stats[:compression_ratio]} times smaller
            while preserving #{stats[:preserved_information]} of the important information.
          SUMMARY
        end

        private

        def validate_input(df)
          unless df.is_a?(Polars::DataFrame)
            raise ArgumentError, "Input must be a Polars DataFrame"
          end
        end

        def get_embedding_columns(df)
          # Assumes embedding columns are numeric and have a pattern like 'embedding_0', 'embedding_1', etc.
          # Adjust this logic if your embedding columns follow a different naming convention
          df.columns.select { |col| col.match(/^embedding_\d+$/) || col.match(/^vector_\d+$/) }
        end

        def df_to_narray(df, embedding_columns)
          # Convert embedding columns from DataFrame to Numo::NArray
          x = Numo::DFloat.zeros([df.height, embedding_columns.length])

          embedding_columns.each_with_index do |col, i|
            x[true, i] = Numo::NArray.cast(df[col].to_a)
          end

          x
        end

        def create_result_dataframe(original_df, embedding_columns, transformed_data)
          # Create a copy of the original DataFrame without the embedding columns
          non_embedding_cols = original_df.columns - embedding_columns
          result_df = original_df.select(non_embedding_cols)

          # Add the reduced embedding columns
          transformed_data.shape[1].times do |i|
            col_name = "reduced_embedding_#{i}"
            result_df = result_df.with_column(
              Polars.lit(transformed_data[true, i].to_a).alias(col_name)
            )
          end

          # Add metadata columns about the reduction
          result_df = result_df.with_column(
            Polars.lit(@original_dimensions).alias("original_embedding_dim")
          ).with_column(
            Polars.lit(@reduced_dimensions).alias("reduced_embedding_dim")
          ).with_column(
            Polars.lit(@preserved_variance).alias("preserved_variance")
          )

          result_df
        end
      end
    end
  end
end
