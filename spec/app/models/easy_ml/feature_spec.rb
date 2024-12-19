require "spec_helper"
require "support/model_spec_helper"
require "support/file_spec_helper"

RSpec.describe EasyML::Datasource do
  include ModelSpecHelper

  let(:today) do
    EasyML::Support::EST.parse("2024-10-01")
  end

  before(:each) do
    EasyML::Cleaner.clean
  end

  after(:each) do
    EasyML::Cleaner.clean
  end

  let(:dir) do
    single_file_dir
  end

  let(:datasource) do
    EasyML::Datasource.create(
      name: "Single File",
      datasource_type: "file",
      root_dir: dir,
    )
  end

  let(:dataset) do
    EasyML::Dataset.create(
      name: "My Dataset",
      datasource: datasource,
      splitter_attributes: {
        splitter_type: "date",
        today: today,
        date_col: "created_date",
        months_test: 2,
        months_valid: 2,
      },
    )
  end

  let(:synced_directory) do
    EasyML::Data::SyncedDirectory
  end

  describe "Features" do
    class DidConvert
      include EasyML::Features

      def did_convert(df)
        df.with_column(
          (Polars.col("rev") > 0).alias("did_convert")
        )
      end

      feature :did_convert,
              name: "did_convert",
              description: "Boolean true/false, did the loan application fund?"
    end

    # class Age
    #   include EasyML::Features

    #   def age(df)
    #     df.with_column(
    #       Polars::Series.new("age", Array.new(df.height) { rand(1..50) })
    #     )
    #   end

    #   feature :age,
    #           name: "age",
    #           description: "Age of the owner"
    # end

    # class BusinessInception
    #   include EasyML::Features

    #   def business_inception(df)
    #     df.with_column(
    #       Polars::Series.new("business_inception", Array.new(df.height) do
    #         rand(Date.new(1970, 1, 1)..Date.today - 30.years)
    #       end).alias("business_inception")
    #     )
    #   end

    #   feature :business_inception,
    #           name: "Business Inception",
    #           description: "Business inception date"
    # end

    # class DaysInBusiness
    #   include EasyML::Features

    #   def days_in_business(df)
    #     df.with_column(
    #       (Polars.col("created_date") - Polars.col("business_inception")).dt.days.alias("days_in_business")
    #     )
    #   end

    #   feature :days_in_business,
    #           name: "Days in business",
    #           description: "Days since the business inception date"
    # end

    # class BadFeature
    #   include EasyML::Features

    #   def bad_feature(_df)
    #     "not a dataframe" # Intentionally return wrong type
    #   end

    #   feature :bad_feature,
    #           name: "Bad Feature",
    #           description: "A feature that doesn't return a DataFrame"
    # end

    before do
      EasyML::Features::Registry.register(DidConvert)
      # EasyML::Features::Registry.register(Age)
      # EasyML::Features::Registry.register(BusinessInception)
      # EasyML::Features::Registry.register(DaysInBusiness)
    end

    it "versions features", :focus do
      # Create business_inception first since days_in_business depends on it
      expect(dataset).to be_needs_refresh
      dataset.refresh!
      expect(dataset).to_not be_needs_refresh

      # EasyML::Feature.new(
      #   dataset: dataset,
      #   feature_class: BusinessInception,
      #   feature_method: :business_inception,
      # ).insert

      # EasyML::Feature.new(
      #   dataset: dataset,
      #   feature_class: DaysInBusiness,
      #   feature_method: :days_in_business,
      # ).insert

      # # Insert age between business_inception and days_in_business
      # EasyML::Feature.new(
      #   dataset: dataset,
      #   feature_class: Age,
      #   feature_method: :age,
      # ).insert_after(:business_inception)

      # Prepend did_convert to be first
      EasyML::Feature.new(
        dataset: dataset,
        feature_class: DidConvert,
        feature_method: :did_convert,
      ).prepend

      expect(dataset).to be_needs_refresh
      dataset.refresh!
      expect(dataset).to_not be_needs_refresh

      # Verify the data is computed correctly
      expect(dataset.data["did_convert"].to_a).to eq([false, false, true, true, false, true, true, true])
      expect(dataset.features.find_by(name: "Did Convert").version).to eq(1)

      dataset.bump_versions(dataset.version)
      expect(dataset.features.find_by(name: "Did Convert").version).to eq(2)
    end

    it "raises appropriate error if any feature doesn't return df" do
      # Register the bad feature
      EasyML::Features::Registry.register(BadFeature)

      # Create a feature that will fail
      feature = EasyML::Feature.new(
        dataset: dataset,
        feature_class: BadFeature,
        feature_method: :bad_feature,
      )
      feature.insert

      # Attempt to refresh the dataset
      expect do
        dataset.refresh!
      end.to raise_error(/Feature 'bad_feature' must return a Polars::DataFrame/)
    end
  end
end
