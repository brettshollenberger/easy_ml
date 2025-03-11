class PayrollLeads < EasyML::Dataset
  def view(df)
    df.filter(
      Polars.col("loan_purpose").eq("payroll")
    )
  end
end