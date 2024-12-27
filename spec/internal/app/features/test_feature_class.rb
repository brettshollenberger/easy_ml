class TestFeatureClass
  include EasyML::Features

  feature name: "Test Feature",
          batch_size: 100,
          primary_key: "ID",
          refresh_every: 1.day

  def transform(df, feature)
    df
  end
end
