module EasyML
  module DataframeSerialization
    extend ActiveSupport::Concern

    def serialize_dataframe(df)
      return unless df
      JSON.parse(df.write_json)
    end

    def deserialize_dataframe(df_data)
      return unless df_data.present? && df_data.key?("columns")

      columns = df_data["columns"].map do |col|
        dtype = case col["datatype"]
          when Hash
            if col["datatype"]["Datetime"]
              Polars::Datetime.new(col["datatype"]["Datetime"][0].downcase.to_sym).class
            else
              Polars::Utf8
            end
          else
            Polars.const_get(col["datatype"])
          end
        Polars::Series.new(col["name"], col["values"], dtype: dtype)
      end

      Polars::DataFrame.new(columns)
    end
  end
end
