require "spec_helper"
require "support/model_spec_helper"
require "support/file_spec_helper"

RSpec.describe EasyML::Datasource do
  before(:each) do
    dataset.cleanup
  end

  after(:each) do
    dataset.cleanup
  end

  let(:dataset) do
    EasyML::Dataset.create(
      target: "rev",
      name: "My Dataset",
      datasource: datasource,
      preprocessing_steps: {
        training: {
          annual_revenue: {
            median: true
          }
        }
      },
      splitter: {
        date: {
          today: EST.parse("2024-10-01"),
          date_col: "created_date",
          months_test: 2,
          months_valid: 2
        }
      }
    )
  end

  describe "File datasource" do
    let(:dir) do
      SPEC_ROOT.join("lib/easy_ml/data/dataset/data/files/raw")
    end

    let(:datasource) do
      EasyML::Datasource.create(
        name: "Local dir",
        datasource_type: :file,
        root_dir: dir
      )
    end

    it "saves and reloads the dataset" do
      dataset.refresh!
      dataset.columns.find_by(name: "rev").update(is_target: true)

      reloaded = EasyML::Dataset.find(dataset.id)
      expect(reloaded.datasource).to eq datasource
      expect(reloaded.datasource.data).to eq datasource.data
      expect(reloaded.datasource.data["loan_purpose"].to_a.first).to eq "payroll"
      expect(reloaded.target).to eq "rev"
      expect(reloaded.splitter.today).to eq dataset.splitter.today
      expect(reloaded.splitter.date_col).to eq dataset.splitter.date_col
      expect(reloaded.splitter.months_test).to eq dataset.splitter.months_test
      expect(reloaded.splitter.months_valid).to eq dataset.splitter.months_valid
      expect(reloaded.splitter).to be_a(EasyML::Data::Dataset::Splitters::DateSplitter)

      # The original dataset was processed, so the reloaded one is
      expect(reloaded).to be_processed
      expect(reloaded.train).to be_a(Polars::DataFrame)
    end
  end

  describe "Polars datasource" do
    let(:df) do
      df = Polars::DataFrame.new({
                                   id: [1, 2, 3, 4, 5, 6, 7, 8],
                                   rev: [0, 0, 100, 200, 0, 300, 400, 500],
                                   annual_revenue: [300, 400, 5000, 10_000, 20_000, 30, nil, nil],
                                   points: [1.0, 2.0, 0.1, 0.8, nil, 0.1, 0.4, 0.9],
                                   created_date: %w[2021-01-01 2021-01-01 2022-02-02 2024-01-01 2024-06-15 2024-07-01
                                                    2024-08-01 2024-09-01]
                                 })

      # Convert the 'created_date' column to datetime
      df.with_column(
        Polars.col("created_date").str.strptime(Polars::Datetime, "%Y-%m-%d").alias("created_date")
      )
    end
    let(:datasource) do
      EasyML::Datasource.create(
        name: "dataset",
        datasource_type: :polars,
        df: df
      )
    end

    class DidConvert
      include EasyML::Transforms

      def did_convert(df)
        df.with_column(
          (Polars.col("rev") > 0).alias("did_convert")
        )
      end
      transform :did_convert,
                name: "did_convert",
                description: "Boolean true/false, did the loan application fund?"
    end

    class Age
      include EasyML::Transforms

      def age(df)
        df.with_column(
          Polars::Series.new("age", Array.new(df.height) { rand(1..50) })
        )
      end
      transform :age,
                name: "age",
                description: "Age of the business"
    end
    before do
      EasyML::Transforms::Registry.register(DidConvert)
      EasyML::Transforms::Registry.register(Age)
    end

    it "saves and reloads the dataset" do
      dataset.refresh!
      dataset.columns.find_by(name: "rev").update(is_target: true)

      reloaded = EasyML::Dataset.find(dataset.id)
      expect(reloaded.datasource).to eq datasource
      expect(reloaded.datasource.data).to eq datasource.data
      expect(reloaded.target).to eq "rev"
      expect(reloaded.splitter.today).to eq dataset.splitter.today
      expect(reloaded.splitter.date_col).to eq dataset.splitter.date_col
      expect(reloaded.splitter.months_test).to eq dataset.splitter.months_test
      expect(reloaded.splitter.months_valid).to eq dataset.splitter.months_valid
      expect(reloaded.splitter).to be_a(EasyML::Data::Dataset::Splitters::DateSplitter)

      # It isn't processed, given that it's an in-memory datasource
      expect(reloaded).to_not be_processed
      expect(reloaded.train).to be_nil
      reloaded.refresh!
      expect(reloaded).to be_processed
      expect(reloaded.train).to be_a(Polars::DataFrame)
    end

    it "creates computed columns", :focus do
      EasyML::DatasetTransform.create!(
        dataset: dataset,
        transform_class: DidConvert,
        transform_method: :did_convert
      )

      EasyML::DatasetTransform.create!(
        dataset: dataset,
        transform_class: Age,
        transform_method: :age
      )

      dataset.refresh!
      expect(dataset.data["did_convert"].to_a).to eq([
                                                       false, false, true, true, false, true, true, true
                                                     ])

      # It computes statistics for computed features
      expect(dataset.statistics["age"]["mean"]).to be_between(1, 50)
      expect(dataset.columns.map(&:name)).to include("age")
      expect(dataset.columns.map(&:name)).to include("did_convert")
      expect(dataset.schema["age"]).to eq "integer"
      expect(dataset.schema["did_convert"]).to eq "boolean"
    end
  end
end
