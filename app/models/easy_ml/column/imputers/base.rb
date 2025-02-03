module EasyML
  class Column
    class Imputers
      class Base
        class << self
          def param_applies(p)
            Imputers.supported_params << p
            define_method(:applies?) do
              params.symbolize_keys&.key?(p.to_sym)
            end
          end

          def method_applies(m)
            Imputers.supported_methods << m
            define_method(:applies?) do
              method.to_sym == m.to_sym
            end
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

        def anything?
          true
        end

        def transform(df)
          raise "Method not implemented"
        end
      end
    end
  end
end
