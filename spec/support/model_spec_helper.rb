require "spec_helper"

module ModelSpecHelper
  def self.included(base)
    base.let(:multi_file_dir) do
      SPEC_ROOT.join("internal/easy_ml/datasources/multi_file")
    end

    base.let(:single_file_dir) do
      SPEC_ROOT.join("internal/easy_ml/datasources/single_file")
    end

    base.let(:titanic_core_dir) do
      SPEC_ROOT.join("internal/easy_ml/datasources/titanic_core")
    end

    base.let(:titanic_extended_dir) do
      SPEC_ROOT.join("internal/easy_ml/datasources/titanic_extended")
    end

    base.let(:loans_dir) do
      SPEC_ROOT.join("internal/easy_ml/datasources/loans")
    end

    base.let(:preprocessing_steps) do
      {
        training: {
          annual_revenue: {
            median: true,
            clip: { min: 0, max: 1_000_000 }
          },
          loan_purpose: {
            categorical: {
              categorical_min: 2,
              one_hot: true
            }
          }
        }
      }
    end
    base.let(:target) { "rev" }
    base.let(:date_col) { "date" }
    base.let(:months_test) { 2 }
    base.let(:months_valid) { 2 }
    base.let(:today) { EasyML::Support::EST.parse("2024-06-01") }
    base.let(:df) do
      Polars::DataFrame.new({
                              "id" => [1, 2, 3, 4, 5, 6, 7, 8, 9, 10],
                              "business_name" => ["Business A", "Business B", "Business C", "Business D", "Business E", "Business F",
                                                  "Business G", "Business H", "Business I", "Business J"],
                              "annual_revenue" => [1000, 2000, 3000, 4000, 5000, 6000, 7000, 8000, 9000, 10_000],
                              "loan_purpose" => %w[payroll payroll payroll expansion payroll inventory equipment
                                                   marketing equipment marketing],
                              "state" => %w[VIRGINIA INDIANA WYOMING PA WA MN UT CA DE FL],
                              "rev" => [100, 0, 0, 200, 0, 500, 7000, 0, 0, 10],
                              "date" => %w[2021-01-01 2021-05-01 2022-01-01 2023-01-01 2024-01-01
                                           2024-02-01 2024-02-01 2024-03-01 2024-05-01 2024-06-01]
                            }).with_column(
                              Polars.col("date").str.strptime(Polars::Datetime, "%Y-%m-%d")
                            )
    end

    base.let(:datasource) do
      EasyML::Datasource.create(name: "Polars Datasource", datasource_type: "polars", df: df)
    end

    base.let(:loans_datasource) do
      EasyML::Datasource.create(name: "Loans", datasource_type: "file")
    end

    base.let(:drop_if_null) do
      %w[loan_purpose]
    end

    base.let(:hidden) do
      %w[business_name state date id]
    end

    base.let(:base_dataset_config) do
      {
        name: "My Dataset",
        splitter_attributes: {
          splitter_type: "date",
          today: today,
          date_col: date_col,
          months_test: months_test,
          months_valid: months_valid
        }
      }
    end

    base.let(:dataset_config) do
      base_dataset_config.merge!(
        datasource: datasource
      )
    end

    base.let(:loans_dataset_config) do
      base_dataset_config.merge!(
        datasource: loans_datasource
      )
    end

    base.let(:dataset) do
      make_dataset(dataset_config, nil)
    end

    base.let(:loans_dataset) do
      make_dataset(loans_dataset_config, loans_dir)
    end

    def make_dataset(config, datasource_location = nil)
      mock_s3_download(datasource_location) if datasource_location
      mock_s3_upload

      dataset = EasyML::Dataset.create(**config)
      dataset.refresh

      dataset.columns.find_by(name: target).update(is_target: true)
      dataset.columns.where(name: drop_if_null).update_all(drop_if_null: true)
      dataset.columns.where(name: hidden).update_all(hidden: true)

      update_preprocessing_steps(dataset, preprocessing_steps)
      dataset
    end

    base.let(:learning_rate) { 0.05 }
    base.let(:max_depth) { 8 }
    base.let(:task) { :regression }
    base.let(:objective) { "reg:squarederror" }

    base.let(:base_model_config) do
      {
        name: "My model",
        model_type: "xgboost",
        task: task,
        hyperparameters: {
          booster: :gbtree,
          n_estimators: 1,
          learning_rate: learning_rate,
          max_depth: max_depth,
          objective: objective
        }
      }
    end
    base.let(:model_config) do
      base_model_config.merge!(
        dataset: dataset
      )
    end
    base.let(:loans_model_config) do
      base_model_config.merge!(
        name: "Loans Model",
        dataset: loans_dataset,
        task: :regression
      )
    end

    base.let(:model) do
      EasyML::Model.new(model_config)
    end

    base.let(:loans_model) do
      EasyML::Model.new(loans_model_config)
    end

    # base.before(:each) do
    #   dataset.cleanup
    #   dataset.refresh!
    # end

    # base.after(:each) do
    #   dataset.cleanup
    #   model.cleanup!
    # end
  end

  def build_model(params)
    Timecop.freeze(incr_time)
    EasyML::Model.new(params.reverse_merge!(dataset: dataset, metrics: %w[mean_absolute_error],
                                            task: :regression,
                                            hyperparameters: {
                                              objective: "reg:squarederror"
                                            })).tap do |model|
      model.fit
      model.save
    end
  end

  def incr_time
    @time += 1.second
  end

  private

  def update_preprocessing_steps(dataset, steps)
    return unless steps&.dig(:training)

    steps[:training].each do |column_name, config|
      column = dataset.columns.find_by(name: column_name.to_s)
      next unless column

      method, params = extract_preprocessing_config(config)

      column.update(
        preprocessing_steps: {
          training: {
            method: method,
            params: params
          }
        }
      )
    end
  end

  def extract_preprocessing_config(config)
    if config[:median]
      [:median, { clip: config[:clip] }.compact]
    elsif config[:categorical]
      [:categorical, config[:categorical]]
    else
      raise ArgumentError, "Unknown preprocessing configuration: #{config}"
    end
  end

  def mock_s3_upload
    allow_any_instance_of(EasyML::Data::SyncedDirectory).to receive(:upload).and_return(true)
    allow_any_instance_of(EasyML::Data::SyncedDirectory).to receive(:remote_files).and_return([])
    allow_any_instance_of(Aws::S3::Client).to receive(:put_object) do |_s3_client, args|
      expect(args[:bucket]).to eq "my-bucket"
    end.and_return(true)
  end

  def mock_s3_download(path)
    synced_directory = EasyML::Data::SyncedDirectory
    allow_any_instance_of(synced_directory).to receive(:synced?) do |sync_dir|
      Dir.glob(File.join(sync_dir.root_dir, "**/*.{parquet}")).any?
    end
    allow_any_instance_of(synced_directory).to receive(:sync).and_return(true)
    allow_any_instance_of(synced_directory).to receive(:clean_dir!).and_return(true)
    allow_any_instance_of(synced_directory).to receive(:files_to_sync).and_return(Dir.glob("#{path}/**/*.csv").map do |f|
      OpenStruct.new(key: f)
    end)
    allow_any_instance_of(EasyML::Datasources::S3Datasource).to receive(:exists?).and_return(true)
    allow_any_instance_of(synced_directory).to receive(:download_file).and_return(true)

    reader = EasyML::Data::PolarsReader.new(
      root_dir: path
    )
    allow_any_instance_of(synced_directory).to receive(:reader).and_return(reader)
  end
end
