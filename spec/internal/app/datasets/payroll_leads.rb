class PayrollLeads < EasyML::Dataset
  def materialize_view(df)
    df.filter(
      Polars.col("loan_purpose").eq("payroll")
    )
  end
end