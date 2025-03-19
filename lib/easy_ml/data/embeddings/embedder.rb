module EasyML
  module Data
    class Embeddings
      class Embedder
        attr_accessor :llm, :config, :adapter

        # Provider-specific batch size recommendations
        BATCH_SIZES = {
          openai: 100,     # Conservative default for OpenAI
          anthropic: 100,  # Conservative default for Anthropic
          gemini: 100,    # Conservative default for Google's Gemini
          ollama: 50,     # Local models typically have more limited batch sizes
          default: 100,    # Default for any other provider
        }

        TOKEN_LIMITS = {
          openai: 8191,    # text-embedding-3-small token limit
          anthropic: 8000, # Conservative estimate for Claude
          gemini: 8000,   # Conservative estimate for Gemini
          ollama: 4096,   # Conservative estimate for local models
          default: 8000,  # Conservative default
        }

        ADAPTERS = {
          anthropic: Langchain::LLM::Anthropic,
          gemini: Langchain::LLM::GoogleGemini,
          openai: Langchain::LLM::OpenAI,
          ollama: Langchain::LLM::Ollama,
        }

        DEFAULTS = {
          api_key: {
            anthropic: ENV["ANTHROPIC_API_KEY"],
            gemini: ENV["GEMINI_API_KEY"],
            openai: ENV["OPENAI_API_KEY"],
            ollama: ENV["OLLAMA_API_KEY"],
          },
        }

        def initialize(llm, config = {})
          @llm = llm.to_sym
          @config = config.symbolize_keys
          apply_defaults
        end

        def embed(df, col, output_column)
          pick

          # Create a dataframe of unique texts and their embeddings
          unique_df = df.select(col)
            .filter(Polars.col(col).is_not_null & (Polars.col(col) != ""))
            .unique

          unique_texts = unique_df[col].to_a
          return df if unique_texts.empty?

          unique_embeddings = batch_embed(unique_texts)
          return df if unique_embeddings.empty?

          # Create a new dataframe with text-embedding pairs and ensure types match
          embeddings_df = Polars::DataFrame.new({ col => unique_texts, output_column => unique_embeddings })
            .with_columns(Polars.col(col).cast(df.schema[col]).alias(col))

          # Join with error handling
          begin
            result = df.join(embeddings_df, on: col, how: "left")

            if result.columns.include?("#{output_column}_right")
              result = result.with_columns(
                Polars.when(Polars.col("#{output_column}_right").is_not_null)
                  .then(Polars.col("#{output_column}_right"))
                  .otherwise(Polars.col(output_column))
                  .alias(output_column)
              ).drop("#{output_column}_right")
            end

            result
          rescue => e
            puts "Join failed: #{e.message}"
            puts "Original df columns: #{df.columns.inspect}"
            puts "Embeddings df columns: #{embeddings_df.columns.inspect}"
            puts "Original df schema: #{df.schema.inspect}"
            puts "Embeddings df schema: #{embeddings_df.schema.inspect}"
            raise
          end
        end

        private

        def batch_embed(texts)
          # Skip empty processing
          return [] if texts.nil? || texts.empty?

          # Filter out nil or empty strings
          texts = texts.compact.reject(&:empty?)
          return [] if texts.empty?

          # Get limits based on provider
          batch_size = config[:batch_size] || BATCH_SIZES[@llm] || BATCH_SIZES[:default]
          token_limit = config[:token_limit] || TOKEN_LIMITS[@llm] || TOKEN_LIMITS[:default]

          # Split texts into smaller batches if they might exceed token limit
          # Rough estimate: 4 chars ≈ 1 token
          texts = texts.chunk_while do |text1, text2|
            current_batch_chars = text1.length
            next_batch_chars = current_batch_chars + text2.length
            (next_batch_chars / 4) < token_limit
          end.to_a

          # Get parallel processing settings
          parallel_processes = config[:parallel_processes] || 4
          parallelism_mode = (config[:parallelism_mode] || :threads).to_sym

          # Process in parallel with appropriate error handling
          all_embeddings = []

          texts.each do |batch|
            if parallel_processes > 1
              case parallelism_mode
              when :threads
                embeddings = Parallel.map(batch.each_slice(batch_size), in_threads: parallel_processes) do |sub_batch|
                  with_retries { process_batch(sub_batch) }
                end
              when :processes
                embeddings = Parallel.map(batch.each_slice(batch_size), in_processes: parallel_processes) do |sub_batch|
                  with_retries { process_batch(sub_batch) }
                end
              else
                raise ArgumentError, "parallelism_mode must be :threads or :processes"
              end
              all_embeddings.concat(embeddings)
            else
              # Sequential processing
              batch.each_slice(batch_size) do |sub_batch|
                all_embeddings << with_retries { process_batch(sub_batch) }
              end
            end
          end

          # Flatten the results and return
          all_embeddings.flatten(1)
        end

        def process_batch(batch)
          response = adapter.embed(text: batch)
          unpack(response)
        end

        def unpack(embeddings)
          return [] if embeddings.nil?
          
          raw_response = embeddings.respond_to?(:raw_response) ? embeddings.raw_response : embeddings
          raw_response = raw_response.is_a?(String) ? JSON.parse(raw_response, symbolize_names: true) : raw_response.deep_symbolize_keys
          
          case llm.to_sym
          when :openai
            raw_response.dig(:data)&.map { |e| e[:embedding] } || []
          else
            embeddings
          end
        rescue JSON::ParserError => e
          Rails.logger.error("Failed to parse embeddings response: #{e.message}")
          []
        end

        def with_retries(max_retries: 3, base_delay: 1, max_delay: 60)
          retries = 0
          begin
            yield
          rescue => e
            retries += 1
            if retries <= max_retries
              # Exponential backoff with jitter
              delay = [base_delay * (2 ** (retries - 1)) * (1 + rand * 0.1), max_delay].min
              sleep(delay)
              retry
            else
              raise e
            end
          end
        end

        # These options are pulled from Langchain
        #
        # default_options: {
        #   embeddings_model_name: "text-embedding-3-small",
        # },
        def pick
          @adapter ||= ADAPTERS[@llm].new(**config)
          self
        end

        def apply_defaults
          @config = @config.deep_symbolize_keys

          DEFAULTS.each do |k, v|
            unless @config.key?(k)
              @config[k] = v[@llm]
            end
          end
        end

        def self.constants
          {
            providers: [
              { value: "openai", label: "OpenAI" },
              { value: "anthropic", label: "Anthropic" },
              { value: "ollama", label: "Ollama (Local)" },
            ],
            models: {
              openai: [
                { value: "text-embedding-3-small", label: "text-embedding-3-small", dimensions: 1536 },
                { value: "text-embedding-3-large", label: "text-embedding-3-large", dimensions: 3072 },
                { value: "text-embedding-ada-002", label: "text-embedding-ada-002", dimensions: 1536 },
              ],
              anthropic: [
                { value: "claude-3", label: "Claude 3", dimensions: 3072 },
                { value: "claude-2", label: "Claude 2", dimensions: 1536 },
              ],
              ollama: [
                { value: "llama2", label: "Llama 2", dimensions: 4096 },
                { value: "mistral", label: "Mistral", dimensions: 4096 },
                { value: "mixtral", label: "Mixtral", dimensions: 4096 },
                { value: "nomic-embed-text", label: "Nomic Embed", dimensions: 768 },
                { value: "starling-lm", label: "Starling", dimensions: 4096 },
              ],
            },
            compression_presets: {
              high_quality: {
                description: "Preserves subtle relationships and nuanced meaning",
                variance_target: 0.95,
              },
              balanced: {
                description: "Good balance of quality and storage efficiency",
                variance_target: 0.85,
              },
              storage_optimized: {
                description: "Maximizes storage efficiency while maintaining core meaning",
                variance_target: 0.75,
              },
            },
          }
        end
      end
    end
  end
end
