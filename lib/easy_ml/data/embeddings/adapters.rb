module EasyML
  module Data
    class Embeddings
      class Adapters
        attr_accessor :model, :config

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

        def initialize(model, config = {})
          @model = model.to_sym
          @config = config.symbolize_keys
          apply_defaults
        end

        def embed(df, col)
          pick
          texts = df[col].to_a
          df = df.with_column(
            embeddings: adapter.embed(text: texts),
          )
        end

        private

        def pick
          @adapter ||= ADAPTERS[@model].new(config)
          self
        end

        def apply_defaults
          @config = @config.deep_symbolize_keys

          DEFAULTS.each do |k, v|
            unless @config.key?(k)
              @config[k] = v[@model]
            end
          end
        end
      end
    end
  end
end
