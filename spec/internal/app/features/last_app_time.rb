class LastAppTime
  include EasyML::Features

  def fit(df, feature, options = {})
    batch_df = df.with_columns(
      Polars.col("CREATED_AT").shift(1).over("COMPANY_ID").alias("LAST_APP_TIME")
    )
    batch_df[["COMPANY_ID", "LOAN_APP_ID", "LAST_APP_TIME"]]
  end

  def transform(df, feature)
    stored_df = feature.query(filter: Polars.col("LOAN_APP_ID").is_in(df["LOAN_APP_ID"]))
    df.join(stored_df, on: "LOAN_APP_ID", how: "left")
  end

  feature name: "Last Application Time",
          description: "Time since the company's last loan application",
          primary_key: "LOAN_APP_ID",
          batch_size: 10,
          needs_columns: ["LOAN_APP_ID", "CREATED_AT", "COMPANY_ID"]
end
