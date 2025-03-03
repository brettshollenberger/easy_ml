module EasyML
  module Data
    module PolarsSchema
      def self.serialize(schema)
        schema.deep_symbolize_keys!

        schema.transform_values do |dtype|
          if dtype.is_a?(Hash) && dtype.key?(:type) && dtype.key?(:params)
            dtype
          else
            {
              type: EasyML::Data::PolarsColumn.polars_to_sym(dtype),
              params: dtype_params(dtype),
            }
          end
        end
      end

      def self.deserialize(schema)
        schema.deep_symbolize_keys!

        schema.reduce({}) do |h, (key, type_info)|
          h.tap do
            polars_type = PolarsColumn.sym_to_polars(type_info[:type].to_sym)
            params = deserialize_params(type_info[:params])

            h[key] = initialize_polars_type(polars_type, params)
          end
        end
      end

      def self.simplify(schema)
        schema = serialize(schema)
        schema.transform_values do |hash|
          hash.dig(:type)
        end
      end

      private

      def self.initialize_polars_type(polars_type, params)
        case polars_type.name
        when "Polars::List"
          polars_type.new(params[:inner])
        else
          polars_type.new(**params)
        end
      end

      def self.deserialize_params(params)
        params.reduce({}) do |h, (k, param)|
          h.tap do
            case k.to_sym
            when :inner
              h[:inner] = PolarsColumn.sym_to_polars(param.to_sym)
            else
              h[k] = param
            end
          end
        end
      end

      def self.dtype_params(dtype)
        case dtype
        when Polars::Categorical
          { ordering: dtype.ordering }
        when Polars::Datetime
          {
            time_unit: dtype.time_unit,
            time_zone: dtype.time_zone,
          }
        when Polars::List, Polars::Array
          {
            inner: PolarsColumn.polars_to_sym(dtype.inner),
          }
        else
          {}
        end
      end
    end
  end
end
