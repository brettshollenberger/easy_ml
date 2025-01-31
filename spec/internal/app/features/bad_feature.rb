class BadFeature
  include EasyML::Features

  def computes_columns
    ["bad_feature"]
  end

  def transform(df, feature)
    "not a dataframe" # Intentionally return wrong type
  end

  feature name: "Bad Feature",
          description: "A feature that doesn't return a DataFrame"
end
