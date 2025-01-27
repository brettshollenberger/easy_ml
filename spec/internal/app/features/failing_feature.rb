class FailingFeature
  include EasyML::Features

  def fit(df, feature, options = {})
    raise StandardError, "Intentional failure in feature computation"
  end

  def transform(df, feature)
    df
  end

  feature name: "Failing Feature",
          description: "A feature that always fails during fit",
          batch_size: 10
end
