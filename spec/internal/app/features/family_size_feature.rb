class FamilySizeFeature
  include EasyML::Features

  feature name: "Family Size",
          description: "Combines Parch and SibSp to get total family size",
          primary_key: "PassengerId",
          batch_size: 10

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
    stored_df = feature.query
    binding.pry
    df.join(stored_df, on: "PassengerId", how: "left")
  end
end
