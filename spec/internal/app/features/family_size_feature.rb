class FamilySizeFeature
  include EasyML::Features

  feature name: "Family Size",
          description: "Combines Parch and SibSp to get total family size",
          primary_key: "PassengerId",
          batch_size: 300

  def computes_columns
    ["FamilySize"]
  end

  def fit(df, feature, options = {})
    batch_df = df.with_columns(
      (Polars.col("Parch") + Polars.col("SibSp")).alias("FamilySize")
    )
    batch_df[["PassengerId", "FamilySize"]]
  end

  def transform(df, feature)
    if df.shape[0] == 1
      df["PassengerId"] = (1..df.height).to_a
      df = df.drop("FamilySize") # Drop nulled out version of column
      merge = fit(df, feature)
      df = df.join(merge, on: "PassengerId", how: "left")
      return df
    end

    if df.columns.include?("FamilySize")
      missing_family_size = df.filter(Polars.col("FamilySize").is_null)
      return df if missing_family_size.empty?
      passenger_ids = missing_family_size["PassengerId"]
    else
      passenger_ids = df["PassengerId"]
    end
    stored_df = feature.query(filter: Polars.col("PassengerId").is_in(passenger_ids))
    return df if stored_df.empty?

    df.join(stored_df, on: "PassengerId", how: "left")
  end
end
