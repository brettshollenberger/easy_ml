module EasyML
  module Data
    module PolarsSchema
      def self.serialize(schema)
        schema.transform_values do |dtype|
          {
            type: EasyML::Data::PolarsColumn.polars_to_sym(dtype),
            params: dtype_params(dtype),
          }
        end
      end

      def self.deserialize(schema_hash)
        schema_hash.transform_values do |type_info|
          polars_type = PolarsColumn.sym_to_polars(type_info["type"].to_sym)
          params = type_info["params"]&.transform_keys(&:to_sym) || {}

          polars_type.new(**params)
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
