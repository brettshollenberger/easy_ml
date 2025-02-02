class SimpleFeature
  include EasyML::Features

  def computes_columns
    ["SIMPLE_TIME"]
  end

  def fit(reader, feature)
    df = reader.read(:all, select: ["COMPANY_ID", "CREATED_AT"])
    batch_df = df.with_columns(
      Polars.col("CREATED_AT").alias("SIMPLE_TIME")
    )
    batch_df = batch_df[["COMPANY_ID", "SIMPLE_TIME"]]
    feature.store(batch_df)
  end

  def transform(df, feature)
    stored_df = feature.query
    df.join(stored_df, on: "COMPANY_ID", how: "left")
  end

  feature name: "Simple Time",
          description: "Simple non-partitioned feature",
          batch_size: 10
end
