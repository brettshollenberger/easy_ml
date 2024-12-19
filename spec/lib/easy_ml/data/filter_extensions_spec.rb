require "spec_helper"

RSpec.describe EasyML::Data::FilterExtensions do
  let(:df) { Polars::DataFrame.new(test_data) }
  let(:test_data) do
    [
      { "LOAN_APP_ID" => 5, "LAST_APP_TIME" => "2024-01-01" },
      { "LOAN_APP_ID" => 15, "LAST_APP_TIME" => "2024-01-02" },
    ]
  end

  describe "#is_primary_key_filter?" do
    it "identifies simple equality filters" do
      filter = Polars.col("LOAN_APP_ID").eq(5)
      expect(filter.is_primary_key_filter?).to be true
    end

    it "identifies range filters" do
      filter = Polars.col("LOAN_APP_ID").gt(5)
      expect(filter.is_primary_key_filter?).to be true
    end

    it "identifies compound filters with AND" do
      filter = (Polars.col("LOAN_APP_ID").gt(4) & Polars.col("LOAN_APP_ID").lt(16))
      expect(filter.is_primary_key_filter?).to be true
    end

    it "identifies compound filters with OR" do
      filter = (Polars.col("LOAN_APP_ID").eq(5) | Polars.col("LOAN_APP_ID").eq(15))
      expect(filter.is_primary_key_filter?).to be true
    end

    it "rejects non-primary key filters" do
      filter = Polars.col("LAST_APP_TIME").gt("2024-01-01")
      expect(filter.is_primary_key_filter?).to be false
    end

    it "rejects mixed compound filters" do
      filter = (Polars.col("LOAN_APP_ID").gt(5) & Polars.col("LAST_APP_TIME").gt("2024-01-01"))
      expect(filter.is_primary_key_filter?).to be false
    end
  end

  describe "#extract_primary_key_values" do
    it "extracts values from equality filters" do
      filter = Polars.col("LOAN_APP_ID").eq(5)
      expect(filter.extract_primary_key_values).to contain_exactly(5)
    end

    it "extracts values from range filters" do
      filter = (Polars.col("LOAN_APP_ID").gt(5) & Polars.col("LOAN_APP_ID").lt(15))
      expect(filter.extract_primary_key_values).to contain_exactly(5, 15)
    end

    it "extracts values from IN filters" do
      filter = Polars.col("LOAN_APP_ID").is_in([5, 15])
      expect(filter.extract_primary_key_values).to contain_exactly(5, 15)
    end

    it "extracts values from compound OR filters" do
      filter = (Polars.col("LOAN_APP_ID").eq(5) | Polars.col("LOAN_APP_ID").eq(15))
      expect(filter.extract_primary_key_values).to contain_exactly(5, 15)
    end

    it "handles mixed compound filters" do
      filter = (Polars.col("LOAN_APP_ID").gt(5) & Polars.col("LAST_APP_TIME").gt("2024-01-01"))
      expect(filter.extract_primary_key_values).to contain_exactly(5)
    end
  end
end
