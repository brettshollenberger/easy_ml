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
      let(:df) { manager.data }

      it "filters data based on conditions" do
        filtered = manager.query(df, filter: Polars.col("Age") > 30)
        expect(filtered["Age"].to_a).to all(be > 30)
      end

      it "limits the number of rows returned" do
        limit_size = 5
        limited = manager.query(df, limit: limit_size)
        expect(limited.shape[0]).to eq(limit_size)
      end

      it "selects specific columns" do
        columns = ["Age", "Sex", "Survived"]
        selected = manager.query(df, select: columns)
        expect(selected.columns).to match_array(columns)
      end

      it "returns unique values for specified columns" do
        unique_col = "Sex"
        unique_values = manager.query(df, unique: unique_col, select: unique_col)
        df = manager.query
        expect(unique_values.shape[0]).to be < df.shape[0]
        expect(unique_values.get_column(unique_col).value_counts().shape[0]).to eq(unique_values.shape[0])
      end

      it "sorts data by specified column" do
        sort_col = "Age"
        sorted = manager.query(df, sort: sort_col, filter: Polars.col("Age").is_not_null)["Age"].to_a
        expect(sorted).to eq(sorted.sort)
      end

      it "sorts data in descending order" do
        sort_col = "Age"
        sorted = manager.query(df, sort: sort_col, descending: true, filter: Polars.col("Age").is_not_null)["Age"].to_a
        expect(sorted).to eq(sorted.sort.reverse)
      end
    end
  end

  describe "#store" do
    before(:each) do
      feature_manager.wipe
    end

    after(:each) do
      feature_manager.wipe
    end

    describe "Non-partitioned" do
      let(:feature_manager) do
        described_class.new(
          root_dir: SPEC_ROOT.join("internal/easy_ml/features/family_size"),
          filenames: "family_size",
        )
      end

      it "stores each chunk of the dataframe to a separate file" do
        files = []
        batch_size = 100
        manager.query(batch_size: batch_size) do |batch|
          batch = batch.with_column(
            (Polars.col("SibSp") + Polars.col("Parch")).alias("FamilySize")
          )
          files.push(
            feature_manager.store(batch.select("PassengerId", "FamilySize"))
          )
        end

        last_file_idx = files.size - 1
        files.each.with_index do |file, idx|
          df = manager.query(file)
          if idx == last_file_idx
            # Last batch size is the remainder of the total size
            expect(df.shape[0]).to eq(manager.query.shape[0] % batch_size)
          else
            expect(df.shape[0]).to eq(batch_size)
          end
        end

        (1..9).each do |i|
          expect(files[i - 1]).to eq(feature_manager.root_dir.join("family_size.#{i}.parquet").to_s)
        end

        expect(manager.query.shape[0]).to eq(feature_manager.query.shape[0])

        # It compacts partitions
        feature_manager.compact
        expect(feature_manager.files).to eq([feature_manager.root_dir.join("compacted.parquet").to_s])

        expect(manager.query.shape[0]).to eq(feature_manager.query.shape[0])
      end
    end

    describe "Partitioned" do
      let(:feature_manager) do
        described_class.new(
          root_dir: SPEC_ROOT.join("internal/easy_ml/features/family_size"),
          filenames: "family_size",
          partition: true,
          partition_size: 100,
          primary_key: "PassengerId",
        )
      end

      it "stores each chunk based on partition" do
        files = []
        batch_size = 100

        # Essentially randomly sort these so the partitioned writer has to write to multiple files
        manager.query(batch_size: batch_size, batch_key: "Name") do |batch|
          batch = batch.with_column(
            (Polars.col("SibSp") + Polars.col("Parch")).alias("FamilySize")
          )
          files.push(
            feature_manager.store(batch.select("PassengerId", "FamilySize")).flatten
          )
        end
        files = files.flatten
        expect(feature_manager.files.sort).to eq(files.sort)

        # It compacts partitions
        feature_manager.compact
        (1..9).each do |i|
          expect(feature_manager.files[i - 1]).to eq(feature_manager.root_dir.join("compacted/family_size.#{i}.parquet").to_s)
        end

        expect(manager.query.shape[0]).to eq(feature_manager.query.shape[0])
      end
    end
  end
end
