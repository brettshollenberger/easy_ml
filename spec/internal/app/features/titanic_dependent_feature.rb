class TitanicDependentFeature
  include EasyML::Features

  feature name: "Dependent feature",
          description: "Combines family size plus one",
          primary_key: "PassengerId",
          batch_size: 10

  def computes_columns
    ["FamilySizePlusOne"]
  end

  def transform(df, feature)
    raise "Feature#transform called before feature#fit" unless df.columns.include?("FamilySize")

    df = df.with_column(
      (Polars.col("FamilySize") + 1).alias("FamilySizePlusOne")
    )
    df
  end
end
