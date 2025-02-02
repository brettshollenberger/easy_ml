class FeatureV1
  include EasyML::Features

  def computes_columns
    ["test_feature"]
  end

  def fit(df, feature, options = {})
    df
  end

  def transform(df, feature)
    df["test_feature"] = (1..df.height).to_a
    df
  end

  feature name: "Test Feature V1",
          description: "A test feature that adds test values [1,2,3]"
end

EasyML::Features::Registry.register(FeatureV1)
