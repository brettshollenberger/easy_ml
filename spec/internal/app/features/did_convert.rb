class DidConvert
  include EasyML::Features

  def transform(df, feature)
    df.with_column(
      (Polars.col("rev") > 0).alias("did_convert")
    )
  end

  feature name: "did_convert",
          description: "Boolean true/false, did the loan application fund?"
end
