module EasyML
  module DataframeSerialization
    extend ActiveSupport::Concern

    def serialize_dataframe(df)
      return unless df
      JSON.parse(df.write_json)
    end

    def deserialize_dataframe(df_data)
      Polars::DataFrame.new(df_data)
    end
  end
end
