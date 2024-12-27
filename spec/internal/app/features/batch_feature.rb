class BatchFeature
  include EasyML::Features

  def batch(reader, feature)
    reader.query(select: ["COMPANY_ID"], unique: true)["COMPANY_ID"]
  end

  def fit(reader, feature, options = {})
    batch_start = options.dig(:batch_start)
    batch_end = options.dig(:batch_end)

    df = reader.query(
      filter: Polars.col("COMPANY_ID").is_in((batch_start..batch_end).to_a),
      sort: ["COMPANY_ID", "ID"],
    )

    df.with_columns(
      Polars.col("CREATED_AT").shift(1).over("COMPANY_ID").alias("LAST_APP_TIME")
    )[["ID", "LAST_APP_TIME"]]
  end

  def transform(df, feature)
    stored_df = feature.query(filter: Polars.col("ID").is_in(df["ID"]))
    return df if stored_df.empty?

    df.join(stored_df, on: "ID", how: "left")
  end

  feature name: "Batch Feature",
          description: "A feature that processes in batches",
          batch_size: 10,
          primary_key: "ID"
end
