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

        attr_reader :original_dimensions, :reduced_dimensions, :preserved_variance,
                    :compression_ratio, :storage_savings, :preset_used
        attr_accessor :preset, :dimensions, :column, :embedding_column, :fit, :pca_model

        def initialize(config = {})
          @preset = config.dig(:preset)
          @dimensions = config.dig(:dimensions)

          unless @preset || @dimensions
            @preset = :full
          end
          @pca_model = config.dig(:pca_model)
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

        def compress(df, column, embedding_column, fit: false)
          @column = column
          @embedding_column = embedding_column
          @fit = fit

          if preset.present?
            reduce_with_preset(df, preset: preset)
          else
            reduce_to_dimensions(df, target_dimensions: dimensions)
          end
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

          # Convert embedding columns to Numo::NArray for Rumale
          x = df_to_narray(embeddings_df, embedding_column)
          @original_dimensions = x.shape[1]

          if target_dimensions >= @original_dimensions
            return embeddings_df.clone()
          end

          # Initialize and fit PCA
          @pca_model = Rumale::Decomposition::PCA.new(n_components: target_dimensions)
          transformed = @pca_model.fit_transform(x)

          # Create new dataframe with reduced embeddings
          result_df = create_result_dataframe(embeddings_df, embedding_column, transformed)

          result_df
        end

        # Reduce dimensions to preserve a target variance
        def reduce_to_variance(embeddings_df, target_variance:)
          validate_input(embeddings_df)

          # Convert embedding columns to Numo::NArray for Rumale
          x = df_to_narray(embeddings_df, embedding_column)

          # Get original dimensions from the first embedding
          @original_dimensions = x.shape[1]

          # Calculate the target number of components based on variance preservation
          target_components = (@original_dimensions * target_variance).ceil

          # First fit PCA with all components to analyze variance
          @pca_model = Rumale::Decomposition::PCA.new(n_components: target_components)
          x = @pca_model.fit_transform(x)

          # # Find number of components needed for target variance
          # cumulative_variance = Numo::NArray.cast(@reducer.explained_variance_ratio).cumsum
          # n_components = (cumulative_variance >= target_variance).where[0]
          # n_components = n_components.nil? ? @original_dimensions : n_components + 1

          # # Apply PCA with determined number of components
          # @reducer = Rumale::Decomposition::PCA.new(n_components: n_components)
          # transformed = @reducer.fit_transform(x)

          # Explainer.new(@reducer, @original_dimensions, n_components)

          # Create new dataframe with reduced embeddings
          result_df = create_result_dataframe(embeddings_df, embedding_column, x)

          result_df
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

        def df_to_narray(df, embedding_column)
          Numo::DFloat.cast(df[embedding_column].to_a)
        end

        def create_result_dataframe(original_df, embedding_column, transformed_data)
          original_df.with_column(
            Polars.lit(transformed_data).alias(embedding_column)
          )
        end
      end
    end
  end
end
