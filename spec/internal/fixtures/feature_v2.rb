class FeatureV1
  include EasyML::Features

  def transform(df, feature)
    df["test_feature"] = [4, 5, 6]  # Changed values
    df
  end

  feature name: "Test Feature V1",
          description: "A test feature that adds test values [4,5,6]"
end

EasyML::Features::Registry.register(FeatureV1)
