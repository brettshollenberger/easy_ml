require "spec_helper"
require "support/model_spec_helper"
require_rails_files

RSpec.describe EasyML::Data::DatasetManager do
  include ModelSpecHelper

  let(:manager) do
    described_class.new(
      root_dir: titanic_extended_dir,
    )
  end

  describe "#query" do
    describe "querying files" do
      let(:files) { manager.files }

      it "filters data based on conditions" do
        filtered = manager.query(filter: Polars.col("Age") > 30)
        expect(filtered["Age"].to_a).to all(be > 30)
      end

      it "filters data based on conditions" do
        filtered = manager.query(filter: Polars.col("Age") > 30)
        expect(filtered["Age"].to_a).to all(be > 30)
      end

      it "limits the number of rows returned" do
        limit_size = 5
        limited = manager.query(limit: limit_size)
        expect(limited.shape[0]).to eq(limit_size)
      end

      it "selects specific columns" do
        columns = ["Age", "Sex", "Survived"]
        selected = manager.query(select: columns)
        expect(selected.columns).to match_array(columns)
      end

      it "returns unique values for specified columns" do
        unique_col = "Sex"
        unique_values = manager.query(unique: unique_col, select: unique_col)
        df = manager.query
        expect(unique_values.shape[0]).to be < df.shape[0]
        expect(unique_values.get_column(unique_col).value_counts().shape[0]).to eq(unique_values.shape[0])
      end

      it "sorts data by specified column" do
        sort_col = "Age"
        sorted = manager.query(sort: sort_col, filter: Polars.col("Age").is_not_null)["Age"].to_a
        expect(sorted).to eq(sorted.sort)
      end

      it "sorts data in descending order" do
        sort_col = "Age"
        sorted = manager.query(sort: sort_col, descending: true, filter: Polars.col("Age").is_not_null)["Age"].to_a
        expect(sorted).to eq(sorted.sort.reverse)
      end
    end

    describe "lazy querying files" do
      let(:files) { manager.files }

      it "filters data based on conditions" do
        filtered = manager.query(lazy: true).filter(Polars.col("Age") > 30).collect
        expect(filtered["Age"].to_a).to all(be > 30)
      end

      it "limits the number of rows returned" do
        limit_size = 5
        limited = manager.query(lazy: true).limit(limit_size).collect
        expect(limited.shape[0]).to eq(limit_size)
      end

      it "selects specific columns" do
        columns = ["Age", "Sex", "Survived"]
        selected = manager.query(lazy: true).select(columns).collect
        expect(selected.columns).to match_array(columns)
      end

      it "returns unique values for specified columns" do
        unique_col = "Sex"
        unique_values = manager.query(lazy: true).select(unique_col).unique.collect
        df = manager.query
        expect(unique_values.shape[0]).to be < df.shape[0]
        expect(unique_values.get_column(unique_col).value_counts().shape[0]).to eq(unique_values.shape[0])
      end

      it "sorts data by specified column" do
        sort_col = "Age"
        sorted = manager.query(lazy: true).sort(sort_col).filter(Polars.col("Age").is_not_null).collect["Age"].to_a
        expect(sorted).to eq(sorted.sort)
      end

      it "sorts data in descending order" do
        sort_col = "Age"
        sorted = manager.query(lazy: true).sort(sort_col, reverse: true).filter(Polars.col("Age").is_not_null).collect["Age"].to_a
        expect(sorted).to eq(sorted.sort.reverse)
      end
    end

    describe "querying in batches" do
      let(:batch_size) { 100 }

      it "yields batches of specified size" do
        batches = []
        manager.query(batch_size: batch_size) { |batch|
          batch = batch.collect
          expect(batch.shape[0]).to be <= batch_size
          batches << batch
        }

        total_rows = batches.sum { |b| b.shape[0] }
        expect(total_rows).to eq(manager.data.shape[0])
      end

      it "identifies or creates a column for batch iteration" do
        df = nil
        manager.query(batch_size: batch_size) do |batch|
          batch = batch.collect
          df = df.nil? ? batch : Polars.concat([df, batch])
        end
        # Should either have PassengerId or a row_number column
        expect(["PassengerId"] & df.columns).not_to be_empty
        expect(df.shape[0]).to eq(manager.data.shape[0])
      end

      it "yields batches starting from specified offset" do
        batches = []
        manager.query(batch_size: batch_size, batch_start: 200) do |batch|
          batch = batch.collect
          batches.push(batch)
        end

        # expect no batch_overlap between batches
        batches.each_cons(2) { |a, b|
          expect(a["PassengerId"].to_a.max).to be < b["PassengerId"].to_a.min
        }
        expect(batches[0]["PassengerId"].to_a.min).to eq(200)
      end

      it "yields enumerable when no block given" do
        batches = []
        batcher = manager.query(batch_size: batch_size)
        batcher.each do |batch|
          batch = batch.collect
          batches.push(batch)
        end

        # expect no batch_overlap between batches
        batches.each_cons(2) { |a, b|
          expect(a["PassengerId"].to_a.max).to be < b["PassengerId"].to_a.min
        }
      end

      it "uses specified batch key when provided" do
        batches = []
        manager.query(batch_size: batch_size, batch_key: "Name") do |batch|
          batch = batch.collect
          batches.push(batch)
        end

        # Verify batches are ordered by Name
        batches.each_cons(2) { |a, b|
          expect(a["Name"].to_a.max).to be < b["Name"].to_a.min
        }
      end

      it "raises error when no columns are specified" do
        columns = ["Sex", "Age", "SibSp", "Parch", "Ticket", "Fare", "Cabin", "Embarked"]
        batches = []
        expect {
          manager.query(batch_size: batch_size, select: columns) do |batch|
            expect(batch.columns).to include("RowNum")
            expect(batch.columns).to match_array(columns + ["RowNum"])
            batches.push(batch)
          end
        }.to raise_error(RuntimeError)
      end
    end

    describe "querying dataframes" do
    end
  end
end
