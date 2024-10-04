require "spec_helper"

PROJECT_ROOT = Pathname.new(File.expand_path("..", __dir__))

RSpec.describe EasyML::Data::Dataset do
  describe "Polars Dataset" do
    let(:df) do
      df = Polars::DataFrame.new({
                                   id: [1, 2, 3, 4, 5, 6, 7, 8],
                                   rev: [0, 0, 100, 200, 0, 300, 400, 500],
                                   annual_revenue: [300, 400, 5000, 10_000, 20_000, 30, nil, nil],
                                   created_date: %w[2021-01-01 2021-01-01 2022-02-02 2024-01-01 2024-06-15 2024-07-01
                                                    2024-08-01 2024-09-01]
                                 })

      # Convert the 'created_date' column to datetime
      df.with_column(
        Polars.col("created_date").str.strptime(Polars::Datetime, "%Y-%m-%d").alias("created_date")
      )
    end

    let(:dataset) do
      EasyML::Data::Dataset.new(
        target: "rev",
        datasource: df,
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

    describe "#initialize" do
      it "sets up the dataset with correct attributes" do
        dataset.refresh!
        x_train, = dataset.train(split_ys: true)
        x_test, = dataset.test(split_ys: true)
        x_valid, = dataset.valid(split_ys: true)

        expect(x_train.count).to eq 4
        expect(x_test.count).to eq 2
        expect(x_valid.count).to eq 2

        expect(dataset.raw).to be_a(EasyML::Data::Dataset::InMemorySplit)
        expect(dataset.processed).to be_a(EasyML::Data::Dataset::InMemorySplit)

        # Median applied
        expect(x_valid["annual_revenue"].to_a).to all(eq(2_700))
      end
    end
  end

  describe "File Datasource" do
    let(:root_dir) { PROJECT_ROOT.join("spec/lib/ml/data/dataset/files/raw") }
    let(:raw_files) { %w[1 2 3].map { |n| PROJECT_ROOT.join(root_dir, "dataset/files/raw/#{n}.csv") }.map(&:to_s) }
    let(:today) { EST.parse("2024-07-01") }

    let(:polars_args) do
      {
        dtypes: {
          'id': "i64",
          'business_name': "str",
          'annual_revenue': "f64",
          'rev': "f64",
          'date': "datetime"
        }
      }
    end

    let(:dataset) do
      EasyML::Data::Dataset.new(
        target: "rev",
        datasource: root_dir,
        polars_args: polars_args,
        preprocessing_steps: {
          training: {
            annual_revenue: {
              median: true
            }
          }
        },
        splitter: {
          date: {
            today: today,
            date_col: "date",
            months_test: 2,
            months_valid: 2
          }
        }
      )
    end

    describe "#initialize" do
      it "sets up the dataset with correct attributes" do
        dataset.cleanup
        dataset.refresh!
        x_train, = dataset.train(split_ys: true)
        x_test, = dataset.test(split_ys: true)
        x_valid, = dataset.valid(split_ys: true)

        expect(x_train.count).to eq 7
        expect(x_test.count).to eq 1
        expect(x_valid.count).to eq 2

        expect(dataset.raw).to be_a(EasyML::Data::Dataset::FileSplit)
        expect(dataset.processed).to be_a(EasyML::Data::Dataset::FileSplit)

        # Median applied
        expect(x_valid["annual_revenue"].to_a).to all(eq(4_000))
        dataset.cleanup
      end
    end
  end

  describe "S3 Dataset" do
    let(:dataset) do
      EasyML::Data::Dataset.new(**config)
    end

    def prepare_test(dataset)
      dataset.cleanup

      allow_any_instance_of(SyncedDirectory).to receive(:synced?).and_return(false)
      allow_any_instance_of(SyncedDirectory).to receive(:sync).and_return(true)
      allow_any_instance_of(SyncedDirectory).to receive(:clean_dir!).and_return(true)
      allow_any_instance_of(s3_datasource).to receive(:refresh!).and_return(true)
      allow_any_instance_of(EasyML::Data::Dataset).to receive(:should_split?).and_return(true)
    end

    describe "When passing in args" do
      let(:s3_datasource) do
        EasyML::Data::Datasource::S3Datasource
      end

      let(:s3_bucket) { "test-bucket" }
      let(:root_dir) { PROJECT_ROOT.join("spec/lib/ml/data") }
      let(:raw_files) { %w[1 2 3].map { |n| PROJECT_ROOT.join(root_dir, "dataset/files/raw/#{n}.csv") }.map(&:to_s) }
      let(:s3_prefix) { "raw" }
      let(:polars_args) do
        {
          dtypes: {
            'id': "i64",
            'business_name': "str",
            'annual_revenue': "f64",
            'rev': "f64",
            'date': "datetime"
          }
        }
      end

      let(:preprocessing_steps) do
        {
          training: {
            annual_revenue: {
              median: true,
              clip: { min: 0, max: 1_000_000 }
            }
          }
        }
      end

      let(:target) { "rev" }
      let(:date_col) { "date" }
      let(:months_test) { 2 }
      let(:months_valid) { 2 }
      let(:today) { EST.parse("2024-07-01") }

      class Transforms
        include EasyML::Transforms

        def transform_state(df)
          binding.pry
        end
        transform :transform_state
      end

      let(:config) do
        {
          root_dir: root_dir,
          verbose: false,
          polars_args: polars_args,
          batch_size: 3,
          drop_if_null: [
            "loan_purpose"
          ],
          transforms: Transforms,
          drop_cols: [
            "CHEATING"
          ],
          datasource: {
            s3: {
              s3_bucket: s3_bucket,
              s3_prefix: s3_prefix,
              s3_access_key_id: "12345",
              s3_secret_access_key: "12345"
            }
          },
          target: target,
          preprocessing_steps: preprocessing_steps,
          splitter: {
            date: {
              today: today,
              date_col: date_col,
              months_test: months_test,
              months_valid: months_valid
            }
          }
        }
      end

      before(:each) do
        prepare_test(dataset)
      end

      after(:each) do
        dataset.cleanup
      end

      describe "#initialize" do
        it "sets up the dataset with correct attributes", :focus do
          expect(dataset.datasource).to be_a(EasyML::Data::Datasource::S3Datasource)
          expect(dataset.target).to eq(target)
          expect(dataset.splitter).to be_a(EasyML::Data::Dataset::Splitters::DateSplitter)
          expect(dataset.raw).to be_a(EasyML::Data::Dataset::Split)
          expect(dataset.processed).to be_a(EasyML::Data::Dataset::Split)
        end
      end

      describe "Splitting raw data into files" do
        describe "#refresh!" do
          it "splits the data into train, test, and valid chunks" do
            expect(dataset).to receive(:split_data).and_call_original
            dataset.refresh!
            expect(dataset.datasource.files).to eq(raw_files)

            train_df = dataset.raw.train
            test_df = dataset.raw.test
            valid_df = dataset.raw.valid

            expect(train_df.shape[0]).to eq 7 # 7 rows
            expect(test_df.shape[0]).to eq 1 # 1 row
            expect(valid_df.shape[0]).to eq 2 # 2 rows
          end

          it "normalizes the final dataset (including removing rows w/ columns that can't be null)" do
            dataset.refresh!

            train_df = dataset.train
            test_df = dataset.test
            valid_df = dataset.valid

            expect(train_df.shape[0]).to eq 7 # 7 rows
            expect(test_df.shape[0]).to eq 1 # 1 row
            expect(valid_df.shape[0]).to eq 1 # Dropped 1 null
          end
        end

        describe "#sync" do
          it "syncs the s3 directory before returning data" do
            expect(dataset.datasource.synced_directory).to receive(:sync)
            dataset.refresh!
          end
        end
      end

      describe "Sample" do
        it "automatically samples a smaller percentage of the dataset" do
          dataset.refresh!
          full_train_df = dataset.train

          dataset.sample = 0.1
          dataset.refresh!

          train_df = dataset.train

          # Calculate the percentage of rows in the sampled dataset
          sample_percentage = (train_df.shape[0].to_f / full_train_df.shape[0]) * 100

          # Check if the sample size is between 30% and 50% of the full dataset
          expect(sample_percentage).to be_between(10, 30)
        end
      end

      describe "Preprocessing steps" do
        it "Automatically manages preprocessing steps, and separates raw from processed data" do
          dataset.refresh!

          dataset.train
          test_df = dataset.test
          dataset.valid

          expect(test_df["annual_revenue"][-1]).to_not be_nil
          expect(test_df["annual_revenue"][-1]).to eq dataset.statistics("development").dig("annual_revenue", "median",
                                                                                            :median, :value)

          # It maintains a separate copy of the RAW dataset, which is not overridden
          raw_test_df = dataset.raw.test
          expect(raw_test_df["annual_revenue"][-1]).to be_nil
        end

        it "removes drop_cols" do
          dataset.refresh!

          train_df = dataset.train
          expect(train_df.columns).to_not include "CHEATING"
        end

        it "keeps drop_cols if requested" do
          dataset.refresh!

          train_df = dataset.train(all_columns: true)
          expect(train_df.columns).to include "CHEATING"
        end
      end

      describe "Transforms" do
        it "enables arbitrary column transforms" do
          dataset.refresh!

          train_df = dataset.train
          test_df = dataset.test
          valid_df = dataset.valid

          allowed_states = Bart::Dataset::Transforms::ALLOWED_US_STATES

          expect(train_df["STATE"].to_a).to all(be_in(allowed_states))
          expect(test_df["STATE"].to_a).to all(be_in(allowed_states))
          expect(valid_df["STATE"].to_a).to all(be_in(allowed_states))
        end
      end

      describe "#train, #test, and #valid" do
        it "delegates to raw before processing has occurred" do
          expect(dataset.raw).to receive(:read).with(:train, any_args).and_call_original
          dataset.train do |df|
            # do nothing
          end
        end

        it "delegates to processed as processing" do
          dataset.refresh!
          expect(dataset.processed).to receive(:read).with(:train, any_args).and_call_original
          dataset.train do |df|
            # do nothing
          end
        end

        it "splits ys when requested" do
          dataset.refresh!

          x_train, y_train = dataset.train(split_ys: true)

          expect(y_train.columns).to include("rev")
          expect(x_train.columns).to_not include("rev")
        end
      end

      describe "#check_nulls" do
        before do
          dataset.refresh!
        end

        context "when there are nulls in the dataset" do
          it "returns a hash with columns containing nulls and their percentages" do
            train_df = Polars::DataFrame.new({
                                               "id" => [1, 2, 3, 4, nil],
                                               "rev" => [100, 200, nil, 400, 500],
                                               "no_nulls" => [1, 2, 3, 4, 5]
                                             })
            test_df = Polars::DataFrame.new({
                                              "id" => [6, 7, 8, 9, 10],
                                              "rev" => [600, nil, 800, 900, 1000],
                                              "no_nulls" => [6, 7, 8, 9, 10]
                                            })
            valid_df = Polars::DataFrame.new({
                                               "id" => [11, 12, nil, 14, 15],
                                               "rev" => [1100, 1200, 1300, 1400, 1500],
                                               "no_nulls" => [11, 12, 13, 14, 15]
                                             })

            allow(dataset.processed).to receive(:read).with(:train) do |&block|
              block.call(train_df)
            end
            allow(dataset.processed).to receive(:read).with(:test) do |&block|
              block.call(test_df)
            end
            allow(dataset.processed).to receive(:read).with(:valid) do |&block|
              block.call(valid_df)
            end

            expected_result = {
              "id" => { train: 20.0, test: 0.0, valid: 20.0 },
              "rev" => { train: 20.0, test: 20.0, valid: 0.0 }
            }

            expect(dataset.check_nulls).to eq(expected_result)
          end
        end

        context "when there are no nulls in the dataset" do
          it "returns nil" do
            allow(dataset.processed).to receive(:read).with(:train).and_return(Polars::DataFrame.new({
                                                                                                       "id" => [1, 2,
                                                                                                                3],
                                                                                                       "rev" => [100,
                                                                                                                 200, 300]
                                                                                                     }))
            allow(dataset.processed).to receive(:read).with(:test).and_return(Polars::DataFrame.new({
                                                                                                      "id" => [4, 5],
                                                                                                      "rev" => [400,
                                                                                                                500]
                                                                                                    }))
            allow(dataset.processed).to receive(:read).with(:valid).and_return(Polars::DataFrame.new({
                                                                                                       "id" => [6, 7],
                                                                                                       "rev" => [600,
                                                                                                                 700]
                                                                                                     }))

            expect(dataset.check_nulls).to be_nil
          end
        end
      end

      describe "private methods" do
        describe "#should_split?" do
          before do
            allow_any_instance_of(EasyML::Data::Dataset).to receive(:should_split?).and_call_original
          end

          context "when split is outdated" do
            before do
              allow(dataset.raw).to receive(:split_at).and_return(Time.now - 2.days)
              allow(dataset.datasource).to receive(:last_updated_at).and_return(Time.now - 1.day)
            end

            it "returns true" do
              expect(dataset.send(:should_split?)).to be true
            end
          end

          context "when split is up-to-date but sample size increases" do
            before do
              allow(dataset.raw).to receive(:split_at).and_return(Time.now)
              allow(dataset.datasource).to receive(:last_updated_at).and_return(Time.now - 1.day)
              allow(dataset).to receive(:load_previous_sample).and_return(0.5)
              dataset.sample = 0.7
            end

            it "returns true" do
              expect(dataset.send(:should_split?)).to be true
            end
          end

          context "when split is up-to-date and sample size decreases" do
            before do
              allow(dataset.raw).to receive(:split_at).and_return(Time.now)
              allow(dataset.datasource).to receive(:last_updated_at).and_return(Time.now - 1.day)
              allow(dataset).to receive(:load_previous_sample).and_return(0.7)
              dataset.sample = 0.5
            end

            it "returns false" do
              expect(dataset.send(:should_split?)).to be false
            end
          end
        end

        describe "#split_data" do
          let(:mock_df) { instance_double(Polars::DataFrame) }
          let(:mock_train_df) { instance_double(Polars::DataFrame) }
          let(:mock_test_df) { instance_double(Polars::DataFrame) }
          let(:mock_valid_df) { instance_double(Polars::DataFrame) }

          before do
            allow(dataset).to receive(:should_split?).and_return(true)
            allow(dataset.datasource).to receive(:in_batches).and_yield(mock_df)
            allow(dataset.splitter).to receive(:split).and_return([mock_train_df, mock_test_df, mock_valid_df])
            allow(dataset.raw).to receive(:save)
            allow(dataset).to receive(:save_previous_sample)
          end

          it "splits and saves data when necessary" do
            expect(dataset.raw).to receive(:cleanup).twice
            expect(dataset.raw).to receive(:save).with(:train, mock_train_df)
            expect(dataset.raw).to receive(:save).with(:test, mock_test_df)
            expect(dataset.raw).to receive(:save).with(:valid, mock_valid_df)
            expect(dataset).to receive(:save_previous_sample).with(dataset.sample)
            dataset.send(:split_data)
          end
        end

        describe "drop_nulls" do
          let(:df) do
            Polars::DataFrame.new({
                                    "col1" => [1, nil, 3],
                                    "col2" => [nil, 2, 3],
                                    "col3" => [nil, nil, nil]
                                  })
          end

          before do
            dataset.drop_if_null = %w[col1 col2]
          end

          it "drops rows with null values in specified columns" do
            result_df = dataset.send(:drop_nulls, df)
            expect(result_df.shape[0]).to eq(1)
            expect(result_df["col1"][0]).to eq(3)
            expect(result_df["col2"][0]).to eq(3)
            expect(result_df["col3"][0]).to be_nil
          end
        end
      end
    end

    # describe "When configuring subclass" do
    #   it "configures via class" do
    #     dataset = Bart::Dataset.new
    #     expect(dataset.datasource).to be_a(EasyML::Data::Datasource::S3Datasource)
    #     expect(dataset.target).to eq("REV")
    #     expect(dataset.splitter).to be_a(EasyML::Data::Dataset::Splitters::DateSplitter)
    #     expect(dataset.raw).to be_a(EasyML::Data::Dataset::Split)
    #   end
    # end
  end
end
