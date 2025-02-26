module EasyML
  module Data
    class Embeddings
      class Compressor
        class Explainer
          attr_accessor :pca, :original_dimensions, :reduced_dimensions

          def initialize(pca, original_dimensions, reduced_dimensions)
            @pca = pca
            @original_dimensions = original_dimensions
            @reduced_dimensions = reduced_dimensions
            explain
          end

          # Get user-friendly stats about the reduction
          def stats
            return nil unless @pca

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
            stats = self.stats
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

          def explain
            # Get centered data
            centered_x = x - @pca.mean

            # If we have lots of samples and relatively few features
            if x.shape[0] > x.shape[1]
              # Calculate covariance matrix using Linalg's matmul for speed
              n_samples = x.shape[0]
              cov_matrix = Numo::Linalg.matmul(centered_x.transpose, centered_x) / (n_samples - 1)

              # Get eigenvalues
              eigenvalues, _ = Numo::Linalg.eigh(cov_matrix)
              eigenvalues = eigenvalues.reverse
            else
              # For high-dimensional data with few samples, use SVD which is faster
              # SVD: X = U * S * V^T, where S^2/(n-1) are the eigenvalues of X^T*X
              _, s, _ = Numo::Linalg.svd(centered_x, driver: "gesdd")
              eigenvalues = (s ** 2) / (x.shape[0] - 1)
            end

            # Calculate variance explained
            @preserved_variance = @pca.explained_variance_ratio.sum
            @reduced_dimensions = target_dimensions
            @compression_ratio = @original_dimensions.to_f / @reduced_dimensions
            @storage_savings = 1.0 - (1.0 / @compression_ratio)
          end
        end
      end
    end
  end
end
