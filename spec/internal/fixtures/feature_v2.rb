class FeatureV1
  include EasyML::Features

  def computes_columns
    ["test_feature"]
  end

  def fit(df, feature, options = {})
    df
  end

  def transform(df, feature)
    df["test_feature"] = df.height.times.map { rand(4..6) }
    df
  end

  feature name: "Test Feature V1",
          description: "A test feature that adds test values [4,5,6]"
end

EasyML::Features::Registry.register(FeatureV1)
