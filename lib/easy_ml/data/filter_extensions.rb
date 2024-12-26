module EasyML
  module Data
    module FilterExtensions
      def is_primary_key_filter?(primary_key)
        return false unless primary_key
        primary_key = [primary_key] unless primary_key.is_a?(Array)
        # Filter expressions in Polars are represented as strings like:
        # [([(col("LOAN_APP_ID")) > (dyn int: 4)]) & ([(col("LOAN_APP_ID")) < (dyn int: 16)])]
        expr_str = to_s
        return false unless expr_str.include?(primary_key.first)

        # Check for common primary key operations
        primary_key_ops = [">", "<", ">=", "<=", "=", "eq", "gt", "lt", "ge", "le"]
        primary_key_ops.any? { |op| expr_str.include?(op) }
      end

      def extract_primary_key_values
        expr_str = to_s
        # Extract numeric values from the expression
        # This will match both integers and floats
        values = expr_str.scan(/(?:dyn int|float): (-?\d+(?:\.\d+)?)/).flatten.map(&:to_f)
        values.uniq
      end
    end
  end
end

# Extend Polars classes with our filter functionality
[Polars::Expr].each do |klass|
  klass.include(EasyML::Data::FilterExtensions)
end
