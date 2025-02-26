module EasyML
  module Data
    class Embeddings
      class Embedder
        attr_accessor :llm, :config, :adapter

        # Provider-specific batch size recommendations
        BATCH_SIZES = {
          openai: 500,    # OpenAI allows up to 2048 items per batch, but 500 is recommended
          anthropic: 100, # Conservative default for Anthropic
          gemini: 100,    # Conservative default for Google's Gemini
          ollama: 50,     # Local models typically have more limited batch sizes
          default: 100,    # Default for any other provider
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
          texts = df[col].to_a
          embeddings = batch_embed(texts)
          df = df.with_column(
            Polars.lit(embeddings).alias(output_column)
          )
        end

        private

        def batch_embed(texts)
          # Skip empty processing
          return [] if texts.nil? || texts.empty?

          # Filter out nil or empty strings
          texts = texts.compact.reject(&:empty?)
          return [] if texts.empty?

          # Get batch size based on provider
          batch_size = config[:batch_size] || BATCH_SIZES[@llm] || BATCH_SIZES[:default]

          # Create batches based on the configured batch size
          batches = texts.each_slice(batch_size).to_a

          # Get parallel processing settings
          parallel_processes = config[:parallel_processes] || 4
          parallelism_mode = (config[:parallelism_mode] || :threads).to_sym

          # Process in parallel with appropriate error handling
          all_embeddings = []

          if parallel_processes > 1 && batches.size > 1
            case parallelism_mode
            when :threads
              all_embeddings = Parallel.map(batches, in_threads: parallel_processes) do |batch|
                with_retries { process_batch(batch) }
              end
            when :processes
              all_embeddings = Parallel.map(batches, in_processes: parallel_processes) do |batch|
                with_retries { process_batch(batch) }
              end
            else
              raise ArgumentError, "parallelism_mode must be :threads or :processes"
            end
          else
            # Sequential processing
            batches.each do |batch|
              all_embeddings << with_retries { process_batch(batch) }
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
          raw_response = embeddings.raw_response.deep_symbolize_keys
          case llm.to_sym
          when :openai
            raw_response.dig(:data).map { |e| e[:embedding] }
          else
            embeddings
          end
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
      end
    end
  end
end
