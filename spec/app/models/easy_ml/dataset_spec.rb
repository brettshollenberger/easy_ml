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

  # preprocessing_steps: {
  #   training: {
  #     annual_revenue: {
  #       median: true
  #     }
  #   }
  # },
  let(:dataset) do
    EasyML::Dataset.create(
      name: "My Dataset",
      datasource: datasource,
      splitter_attributes: {
        splitter_type: "DateSplitter",
        today: EST.parse("2024-10-01"),
        date_col: "created_date",
        months_test: 2,
        months_valid: 2
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
      expect(reloaded.splitter).to be_a(EasyML::DateSplitter)

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
                description: "Age of the owner"
    end

    class BusinessInception
      include EasyML::Transforms

      def business_inception(df)
        df.with_column(
          Polars::Series.new("business_inception", Array.new(df.height) do
            rand(Date.new(1970, 1, 1)..Date.today - 2.years)
          end).alias("business_inception")
        )
      end
      transform :business_inception,
                name: "Business Inception",
                description: "Business inception date"
    end

    class DaysInBusiness
      include EasyML::Transforms

      def days_in_business(df)
        df.with_column(
          (Polars.col("created_date") - Polars.col("business_inception")).dt.days.alias("days_in_business")
        )
      end
      transform :days_in_business,
                name: "Days in business",
                description: "Days since the business inception date"
    end

    class BadTransform
      include EasyML::Transforms

      def bad_transform(_df)
        "not a dataframe" # Intentionally return wrong type
      end
      transform :bad_transform,
                name: "Bad Transform",
                description: "A transform that doesn't return a DataFrame"
    end

    before do
      EasyML::Transforms::Registry.register(DidConvert)
      EasyML::Transforms::Registry.register(Age)
      EasyML::Transforms::Registry.register(BusinessInception)
      EasyML::Transforms::Registry.register(DaysInBusiness)
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
      expect(reloaded.splitter).to be_a(EasyML::DateSplitter)

      # It isn't processed, given that it's an in-memory datasource
      expect(reloaded).to_not be_processed
      expect(reloaded.train).to be_nil
      reloaded.refresh!
      expect(reloaded).to be_processed
      expect(reloaded.train).to be_a(Polars::DataFrame)
    end

    it "creates computed columns in the correct order" do
      # Create business_inception first since days_in_business depends on it
      expect(dataset).to be_needs_refresh
      dataset.refresh!
      expect(dataset).to_not be_needs_refresh

      EasyML::Transform.new(
        dataset: dataset,
        transform_class: BusinessInception,
        transform_method: :business_inception
      ).insert

      EasyML::Transform.new(
        dataset: dataset,
        transform_class: DaysInBusiness,
        transform_method: :days_in_business
      ).insert

      # Insert age between business_inception and days_in_business
      EasyML::Transform.new(
        dataset: dataset,
        transform_class: Age,
        transform_method: :age
      ).insert_after(:business_inception)

      # Prepend did_convert to be first
      EasyML::Transform.new(
        dataset: dataset,
        transform_class: DidConvert,
        transform_method: :did_convert
      ).prepend

      expect(dataset).to be_needs_refresh
      dataset.refresh!
      expect(dataset).to_not be_needs_refresh

      transforms = dataset.transforms.ordered
      expect(transforms.map(&:transform_method)).to eq(
        %w[did_convert business_inception age days_in_business]
      )

      # Verify the data is computed correctly
      expect(dataset.data["did_convert"].to_a).to eq([
                                                       false, false, true, true, false, true, true, true
                                                     ])
      expect(dataset.statistics.dig("raw", "age", "mean")).to be_between(1, 50)
      expect(dataset.data["days_in_business"].to_a).to all(be > 0)
    end

    it "raises appropriate error if any transform doesn't return df" do
      # Register the bad transform
      EasyML::Transforms::Registry.register(BadTransform)

      # Create a transform that will fail
      transform = EasyML::Transform.new(
        dataset: dataset,
        transform_class: BadTransform,
        transform_method: :bad_transform
      )
      transform.insert

      # Attempt to refresh the dataset
      expect do
        dataset.refresh!
      end.to raise_error(/Transform 'bad_transform' must return a Polars::DataFrame/)
    end
  end

  describe "needs_refresh?" do
    let(:df) do
      Polars::DataFrame.new({
                              id: [1, 2, 3],
                              rev: [100, 200, 300],
                              created_date: %w[2024-01-01 2024-02-01 2024-03-01]
                            })
    end

    let(:datasource) do
      EasyML::Datasource.create(
        name: "test_source",
        datasource_type: :polars,
        df: df
      )
    end

    let(:dataset) do
      EasyML::Dataset.create(
        name: "Test Dataset",
        datasource: datasource,
        splitter_attributes: {
          splitter_type: "DateSplitter",
          today: EST.parse("2024-10-01"),
          date_col: "created_date",
          months_test: 2,
          months_valid: 2
        }
      )
    end

    it "returns true when never refreshed (refreshed_at is nil)" do
      expect(dataset.refreshed_at).to be_nil
      expect(dataset).to be_needs_refresh
    end

    context "when previously refreshed" do
      before do
        dataset.refresh!
      end

      it "returns true when columns have been updated" do
        # Travel forward in time to make the update
        Timecop.travel 1.minute do
          dataset.columns.find_by(name: "rev").update!(is_target: true)
        end

        expect(dataset).to be_needs_refresh
      end

      it "returns true when transforms have been updated" do
        Timecop.travel 1.minute do
          EasyML::Transform.create!(
            dataset: dataset,
            transform_class: Age,
            transform_method: :age
          )
        end

        expect(dataset).to be_needs_refresh
      end

      it "returns true when datasource needs refresh" do
        allow(dataset.datasource).to receive(:needs_refresh?).and_return(true)
        expect(dataset).to be_needs_refresh
      end

      it "returns false when nothing has changed" do
        expect(dataset).not_to be_needs_refresh
      end
    end
  end
end
