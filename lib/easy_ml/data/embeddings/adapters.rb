module EasyML
  module Data
    class Embeddings
      class Adapters
        attr_accessor :llm, :config, :adapter

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
          embeddings = unpack(adapter.embed(text: texts))
          df = df.with_column(
            Polars.lit(embeddings).alias(output_column)
          )
        end

        private

        def unpack(embeddings)
          raw_response = embeddings.raw_response.deep_symbolize_keys
          case llm.to_sym
          when :openai
            raw_response.dig(:data).map { |e| e[:embedding] }
          else
            embeddings
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
