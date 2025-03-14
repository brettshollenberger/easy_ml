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

  describe "#store and #compact" do
    before(:each) do
      feature_manager.wipe
    end

    after(:each) do
      feature_manager.wipe
    end

    describe "Simple writer" do
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

    # Will be used by things like train/test/valid sets
    describe "Named writer" do
      let(:feature_manager) do
        described_class.new(
          root_dir: SPEC_ROOT.join("internal/easy_ml/features/family_size"),
          named: true,
        )
      end

      it "stores each named chunk of the dataframe to a separate file" do
        files = []
        batch_size = 100
        num_rows = manager.query(lazy: true).select("PassengerId").collect.shape[0]
        partitions = [
          -1,
          (num_rows * 0.8).round,
          (num_rows * 0.9).round,
          num_rows,
        ]
        chunks = partitions.each_cons(2).to_a
        train, test, valid = chunks.map do |endpoint|
          manager.query(lazy: true).filter(Polars.col("PassengerId").gt(endpoint[0]) & Polars.col("PassengerId").le(endpoint[1])).collect
        end

        feature_manager.store(train, "train")
        feature_manager.store(test, "test")
        feature_manager.store(valid, "valid")

        expect(manager.query.shape[0]).to eq(feature_manager.query.shape[0])
        expect(feature_manager.files.sort).to eq(%w(train test valid).map { |name| feature_manager.root_dir.join("#{name}/1.parquet").to_s }.sort)

        expect(feature_manager.query(file_filter: ->(name) { name.match?(/train/) })).to eq(train)
        expect(feature_manager.query(file_filter: ->(name) { name.match?(/test/) })).to eq(test)
        expect(feature_manager.query(file_filter: ->(name) { name.match?(/valid/) })).to eq(valid)
      end
    end

    describe "Partitioned" do
      describe "Cannot partition non-numeric column" do
        let(:feature_manager) do
          described_class.new(
            root_dir: SPEC_ROOT.join("internal/easy_ml/features/family_size"),
            filenames: "family_size",
            partition: true,
            partition_size: 100,
            primary_key: "Sex",
          )
        end

        it "doesn't partition with non-numeric primary key" do
          df = manager.query(limit: 10).select("Sex")
          feature_manager.store(df.select("Sex"))
          expect(feature_manager.files.count).to eq 1 # Not partitioned
        end
      end

      describe "Numeric partition strategy" do
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
          feature_manager.wipe

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

    describe "Append-only" do
      let(:feature_manager) do
        described_class.new(
          root_dir: SPEC_ROOT.join("internal/easy_ml/features/family_size"),
          filenames: "family_size",
          primary_key: "PassengerId",
          append_only: true,
        )
      end

      it "never wipes chunks" do
        files = []
        batch_size = 100

        filter = Polars.col("PassengerId").le(500)
        manager.query(batch_size: batch_size, filter: filter) do |batch|
          batch = batch.with_column(
            (Polars.col("SibSp") + Polars.col("Parch")).alias("FamilySize")
          )
          files.push(
            feature_manager.store(batch.select("PassengerId", "FamilySize"))
          )
        end
        files = files.flatten.compact
        expect(feature_manager.files.sort).to eq(files.sort)

        # It compacts partitions
        feature_manager.compact

        # Now we finish another round of adding to the store
        # But we'll "accidentally" re-process some of the data
        filter = Polars.col("PassengerId").gt(300)
        manager.query(batch_size: batch_size, filter: filter) do |batch|
          batch = batch.with_column(
            (Polars.col("SibSp") - Polars.col("Parch")).alias("FamilySize")
          )
          feature_manager.store(batch.select("PassengerId", "FamilySize"))
        end
        feature_manager.compact

        # None of the old data was re-added, even though we changed the FamilySize feature computation
        expect(manager.query.shape[0]).to eq(feature_manager.query.shape[0])

        affected_rows = feature_manager.query(filter: Polars.col("PassengerId").is_between(300, 500))
        orig_rows = manager.query(filter: Polars.col("PassengerId").is_between(300, 500))
        affected_rows = affected_rows.join(
          orig_rows,
          on: "PassengerId",
        )[["PassengerId", "FamilySize", "SibSp", "Parch"]]

        # It maintains the old logic (it is append only)
        affected_rows = affected_rows.with_column(
          Polars.col("FamilySize").eq(
            Polars.col("SibSp") + Polars.col("Parch")
          ).alias("Match")
        )
        expect(affected_rows["Match"].to_a).to all(eq true)

        # Once more for good measure, run everything again
        manager.query(batch_size: batch_size) do |batch|
          batch = batch.with_column(
            Polars.lit(42).alias("FamilySize")
          )
          feature_manager.store(batch.select("PassengerId", "FamilySize"))
        end
        feature_manager.compact

        affected_rows = feature_manager.query
        affected_rows = affected_rows.with_column(
          Polars.col("FamilySize").eq(
            Polars.lit(42)
          ).not_.alias("Match")
        )
        expect(affected_rows["Match"].to_a).to all(eq true)
      end
    end
  end
end
