module EasyML
  class Column
    class Imputers
      class Base
        class << self
          def param_applies(p)
            Imputers.supported_params << p
            define_method(:applies?) do
              params.symbolize_keys&.key?(p.to_sym) && params.symbolize_keys.dig(p.to_sym) != false
            end
          end

          def method_applies(m)
            Imputers.supported_methods << m
            define_method(:applies?) do
              method.to_sym == m.to_sym
            end
          end

          def description
            "Unknown preprocessing method"
          end
        end

        attr_accessor :column, :preprocessing_step

        def initialize(column, preprocessing_step)
          @column = column
          @preprocessing_step = preprocessing_step.with_indifferent_access
        end

        def params
          @preprocessing_step.dig(:params)
        end

        def method
          @preprocessing_step.dig(:method)
        end

        def statistics(*args)
          if column.is_computed
            column.statistics.dig(:processed, *args)
          else
            column.statistics.dig(:clipped, *args) || column.statistics.dig(:raw, *args)
          end
        end

        def anything?
          true
        end

        def inspect
          params_str = params ? params.map { |k, v| "#{k}: #{v}" }.join(", ") : "none"
          method_str = method ? method : "none"

          "#<#{self.class.name} method=#{method_str.inspect} params={#{params_str}}>"
        end

        alias_method :to_s, :inspect

        def transform(df)
          raise "Method not implemented"
        end

        def description
          self.class.description
        end
      end
    end
  end
end
