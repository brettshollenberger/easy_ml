class BadFeature
  include EasyML::Features

  def transform(df, feature)
    "not a dataframe" # Intentionally return wrong type
  end

  feature name: "Bad Feature",
          description: "A feature that doesn't return a DataFrame"
end
