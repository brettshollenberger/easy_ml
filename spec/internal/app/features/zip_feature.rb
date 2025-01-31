class ZipFeature
  include EasyML::Features

  def computes_columns
    ["CITY", "STATE", "POPULATION"]
  end

  def fit(df, feature, options = {})
    zip_df = EasyML::Dataset.find_by(name: "Zips").data

    # Join with zip data and return just the columns we need
    df.join(
      zip_df,
      on: "ZIP",
      how: "left",
    )[["ID", "CITY", "STATE", "POPULATION"]]
  end

  def transform(df, feature)
    stored_df = feature.query(filter: Polars.col("ID").is_in(df["ID"]))
    return df if stored_df.empty?

    df.join(stored_df, on: "ID", how: "left")
  end

  feature name: "Zip Feature",
          description: "Adds ZIP code data based on ID",
          batch_size: 10,
          primary_key: "ID"
end
