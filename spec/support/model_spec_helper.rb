require "spec_helper"

module ModelSpecHelper
  def self.included(base)
    base.let(:root_dir) { File.expand_path("..", Pathname.new(__FILE__)) }
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
    base.let(:today) { EST.parse("2024-06-01") }

    base.let(:dataset_config) do
      {
        verbose: false,
        drop_if_null: ["loan_purpose"],
        drop_cols: %w[business_name state date id],
        datasource: EasyML::Data::Datasource::PolarsDatasource.new(df: df),
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

    base.let(:dataset) { EasyML::Data::Dataset.new(**dataset_config) }

    base.let(:hyperparameters) do
      {
        learning_rate: 0.05,
        max_depth: 8,
        n_estimators: 150,
        booster: "gbtree",
        objective: "reg:squarederror"
      }
    end

    base.let(:config) do
      {
        root_dir: root_dir,
        verbose: false,
        hyperparameters: hyperparameters
      }
    end

    base.let(:learning_rate) { 0.05 }
    base.let(:max_depth) { 8 }
    base.let(:task) { :regression }
    base.let(:objective) { "reg:squarederror" }
    base.let(:model_config) do
      {
        root_dir: root_dir,
        model: :xgboost,
        task: task,
        dataset: dataset,
        hyperparameters: {
          learning_rate: learning_rate,
          max_depth: max_depth,
          objective: objective
        }
      }
    end

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

    base.let(:model) do
      EasyML::Model.new(model_config)
    end

    base.before(:each) do
      dataset.cleanup
      dataset.refresh!
      # model.cleanup!
    end

    base.after(:each) do
      dataset.cleanup
      # model.cleanup!
    end
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

  def cleanup
    paths = [
      File.join(root_dir, "xgboost_model.json"),
      File.join(root_dir, "xg_boost.bin")
    ]
    paths.each do |path|
      FileUtils.rm(path) if File.exist?(path)
    end
  end
end
