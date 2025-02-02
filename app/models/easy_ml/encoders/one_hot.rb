module EasyML
  module Encoders
    class OneHot < Base
      def encode(column)
        approved_values = statistics.dig(col, :allowed_categories).sort

        # Create one-hot encoded columns
        approved_values.each do |value|
          new_col_name = "#{col}_#{value}".gsub(/-/, "_")
          df = df.with_column(
            df[col].cast(Polars::String).eq(value.to_s).cast(Polars::Boolean).alias(new_col_name)
          )
        end

        # Create 'other' column for unapproved values
        other_col_name = "#{col}_other"
        df[other_col_name] = df[col].map_elements do |value|
          approved_values.map(&:to_s).exclude?(value)
        end.cast(Polars::Boolean)
        df.drop([col.to_s])
      end
    end
  end
end
