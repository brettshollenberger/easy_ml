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

    base.let(:predefined_splits_dir) do
      SPEC_ROOT.join("internal/easy_ml/datasources/predefined_splits")
    end

    base.let(:loans_dir) do
      SPEC_ROOT.join("internal/easy_ml/datasources/loans")
    end

    base.let(:simple_dir) do
      SPEC_ROOT.join("internal/easy_ml/datasources/simple")
    end

    base.let(:null_dir) do
      SPEC_ROOT.join("internal/easy_ml/datasources/null")
    end

    base.let(:preprocessing_steps) do
      {
        training: {
          annual_revenue: {
            median: true,
            clip: { min: 0, max: 1_000_000 },
          },
          loan_purpose: {
            categorical: {
              categorical_min: 2,
              one_hot: true,
            },
          },
        },
      }
    end
    base.let(:target) { "rev" }
    base.let(:date_col) { "date" }
    base.let(:months_test) { 2 }
    base.let(:months_valid) { 2 }
    base.let(:today) { EasyML::Support::EST.parse("2024-06-01") }
    base.let(:df_with_null_col) do
      Polars::DataFrame.new({
        "id" => [1],
        "null_col" => [nil],
        "rev" => [100],
      })
    end

    base.let(:datasource) do
      loans_datasource
    end

    base.let(:null_datasource) do
      EasyML::Datasource.create(name: "Polars Datasource", datasource_type: "polars", df: df_with_null_col)
    end

    base.let(:loans_datasource) do
      EasyML::Datasource.create(name: "Loans", datasource_type: "file")
    end

    base.let(:simple_datasource) do
      EasyML::Datasource.create(name: "Simple", datasource_type: "file")
    end

    base.let(:single_file_datasource) do
      EasyML::Datasource.create(name: "Single File", datasource_type: "file")
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
          months_valid: months_valid,
        },
      }
    end

    base.let(:dataset_config) do
      base_dataset_config.merge!(
        datasource: datasource,
      )
    end

    base.let(:null_dataset_config) do
      base_dataset_config.merge!(
        datasource: null_datasource,
        splitter_attributes: {
          splitter_type: "random",
        },
      )
    end

    base.let(:loans_dataset_config) do
      base_dataset_config.merge!(
        datasource: loans_datasource,
      )
    end

    base.let(:simple_dataset_config) do
      base_dataset_config.merge!(
        datasource: simple_datasource,
        splitter_attributes: {
          splitter_type: "date",
          today: EasyML::Support::EST.parse("2024-10-01"),
          date_col: "created_date",
          months_test: 2,
          months_valid: 2,
        },
      )
    end

    base.let(:dataset) do
      make_dataset(dataset_config, loans_dir)
    end

    base.let(:loans_dataset) do
      make_dataset(loans_dataset_config, loans_dir)
    end

    base.let(:simple_dataset) do
      make_dataset(simple_dataset_config, simple_dir)
    end

    base.let(:null_dataset) do
      make_dataset(null_dataset_config, null_dir)
    end

    base.let(:features) do
      []
    end

    def make_dataset(config, datasource_location = nil)
      mock_s3_download(datasource_location) if datasource_location
      mock_s3_upload

      dataset = EasyML::Dataset.create(**config)

      features.each do |feature|
        dataset.features.create(
          name: feature.new.computes_columns.first,
          feature_class: feature,
          dataset: dataset,
        )
      end
      dataset.refresh

      dataset.columns.find_by(name: target).update(is_target: true)
      dataset.columns.where(name: drop_if_null).update_all(drop_if_null: true)
      dataset.columns.where(name: hidden).update_all(hidden: true)

      update_preprocessing_steps(dataset, preprocessing_steps)
      dataset.refresh
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
          objective: objective,
        },
      }
    end
    base.let(:model_config) do
      base_model_config.merge!(
        dataset: dataset,
      )
    end
    base.let(:loans_model_config) do
      base_model_config.merge!(
        name: "Loans Model",
        dataset: loans_dataset,
        task: :regression,
        objective: "reg:squarederror",
      )
    end

    base.let(:model) do
      EasyML::Model.new(model_config)
    end

    base.let(:loans_model) do
      EasyML::Model.new(loans_model_config)
    end

    base.let(:loans_model_file_source) do
      Rails.root.join("easy_ml/mocks/models/loans_model/20241205152918.json")
    end

    base.let(:pretrain_loans_model) do
      filename = loans_model_file_source.basename.to_s
      model_file = loans_model.send(:get_model_file)
      allow(model_file).to receive(:root_dir).and_return(loans_model_file_source.dirname)
      model_file.assign_attributes(filename: filename)
      model_file.save
      loans_model.send(:load_model_file)
      loans_model
    end

    def make_titanic_dataset(datasource_location = nil, splitter_attributes)
      dataset = EasyML::Dataset.create(
        name: "Titanic",
        datasource: EasyML::Datasource.new(
          name: datasource_location,
          datasource_type: "file",
        ),
        splitter_attributes: splitter_attributes,
      )
      dataset.refresh
      dataset.columns.find_by(name: "Survived").update(is_target: true)
      dataset.columns.find_by(name: "Name").update(hidden: true)
      dataset.columns.find_by(name: "Cabin").update(hidden: true)
      dataset.columns.find_by(name: "Ticket").update(hidden: true)
      dataset.columns.find_by(name: "Age").update(preprocessing_steps: {
                                                    training: {
                                                      method: :median,
                                                    },
                                                  })
      dataset.columns.find_by(name: "Sex").update(preprocessing_steps: {
                                                    training: {
                                                      method: :categorical,
                                                      params: {
                                                        categorical_min: 2,
                                                        one_hot: true,
                                                      },
                                                    },
                                                  })
      dataset.columns.find_by(name: "Embarked").update(preprocessing_steps: {
                                                         training: {
                                                           method: :categorical,
                                                           params: {
                                                             categorical_min: 2,
                                                             one_hot: true,
                                                           },
                                                         },
                                                       })
      dataset.refresh
      dataset
    end

    base.let(:predefined_dataset) do
      make_titanic_dataset("Predefined Splits", {
        splitter_type: "predefined",
        train_files: ["train.csv"],
        test_files: ["test.csv"],
        valid_files: ["valid.csv"],
      })
    end

    base.let(:titanic_dataset) do
      make_titanic_dataset("Titanic Extended", { splitter_type: :random, seed: 42 })
    end

    base.let(:titanic_model) do
      EasyML::Model.create(
        name: "Titanic",
        slug: "Titanic",
        dataset: titanic_dataset,
        task: :classification,
        objective: "binary:logistic",
        hyperparameters: { n_estimators: 1 },
      )
    end
  end

  def build_model(params)
    Timecop.freeze(incr_time)
    EasyML::Model.new(params.reverse_merge!(dataset: dataset, metrics: %w[mean_absolute_error],
                                            task: :regression,
                                            hyperparameters: {
                                              objective: "reg:squarederror",
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
            params: params,
          },
        },
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
      root_dir: path,
    )
    allow_any_instance_of(synced_directory).to receive(:reader).and_return(reader)
  end

  def randomize_hypers(model)
    model.hyperparameters.learning_rate = rand(0.01..0.1)
    model.hyperparameters.max_depth = rand(3..10)
    model.hyperparameters.regularization = rand(0.1..2.0)
    model.hyperparameters.early_stopping_rounds = rand(10..50)
    model.hyperparameters.min_child_weight = rand(1..10)
    model.hyperparameters.subsample = rand(0.5..1.0)
    model.hyperparameters.colsample_bytree = rand(0.5..1.0)
    model.hyperparameters.colsample_bylevel = rand(0.5..1.0)
    model.hyperparameters.n_estimators = 10
    return unless block_given?

    pos_cases, neg_cases = yield
    model.hyperparameters.scale_pos_weight = (neg_cases / pos_cases).to_f
  end
end
