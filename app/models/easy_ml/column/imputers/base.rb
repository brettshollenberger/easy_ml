module EasyML
  class Column
    class Imputers
      class Base
        class << self
          def param_applies(p)
            Imputers.supported_params << p
            Imputers.params_by_class[self] ||= []
            Imputers.params_by_class[self] << p.to_sym
          end

          def method_applies(m)
            Imputers.supported_methods << m.to_sym
            Imputers.methods_by_class[self] ||= []
            Imputers.methods_by_class[self] << m.to_sym
          end

          def description
            "Unknown preprocessing method"
          end
        end

        cattr_accessor :supported_params, :supported_methods
        attr_accessor :column, :preprocessing_step

        def initialize(column, preprocessing_step)
          @column = column
          @preprocessing_step = preprocessing_step.with_indifferent_access
        end

        def applies?
          method_applies? || param_applies?
        end

        def method_applies?
          imputers_own_methods.include?(method.to_sym)
        end

        def param_applies?
          params.keys.any? { |p| imputers_own_params.include?(p.to_sym) }
        end

        def imputers_own_methods
          Imputers.methods_by_class[self.class] || []
        end

        def imputers_own_params
          Imputers.params_by_class[self.class] || []
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
