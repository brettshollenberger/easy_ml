class FamilySizePlusOneFeature
  include EasyML::Features

  feature name: "Family Size Plus One",
          description: "Combines family size plus one",
          primary_key: "PassengerId",
          batch_size: 10

  def computes_columns
    ["FamilySizePlusOne"]
  end

  def fit(df, feature, options = {})
    family_size_feature = EasyML::Feature.find_by_name("FamilySize")
    passenger_ids = df["PassengerId"].to_a

    # Get the stored FamilySize values for these passengers
    family_size_values = family_size_feature.query(filter: Polars.col("PassengerId").is_in(passenger_ids))

    family_size_plus_one_values = family_size_values.with_columns(
      (Polars.col("FamilySize") + 1).alias("FamilySizePlusOne")
    )

    family_size_plus_one_values[["PassengerId", "FamilySizePlusOne"]]
  end

  def transform(df, feature)
    stored_df = feature.query
    df.join(stored_df, on: "PassengerId", how: "left")
  end
end
