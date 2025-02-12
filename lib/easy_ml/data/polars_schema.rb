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
            params = type_info[:params]&.transform_keys(&:to_sym) || {}

            h[key] = polars_type.new(**params)
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

      def self.dtype_params(dtype)
        case dtype
        when Polars::Categorical
          { ordering: dtype.ordering }
        when Polars::Datetime
          {
            time_unit: dtype.time_unit,
            time_zone: dtype.time_zone,
          }
        else
          {}
        end
      end
    end
  end
end
