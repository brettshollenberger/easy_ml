<img src="easy_ml.svg" alt="EasyML Logo" style="width: 310px; height: 300px;">

# EasyML

~~You can't do machine learning in Ruby.~~

Deploy models in minutes.

## What is EasyML?

EasyML is a **low code/no code**, end-to-end machine learning framework for Ruby on Rails.

**Get productionized models in minutes.** It takes the guesswork out of:

- Preprocessing data
- Storing and batch computing features
- Training models
- Metric visualization
- Deployment and versioning
- Evaluating model performance

With a dead-simple point-and-click interface, EasyML makes it stupid easy to train and deploy.

Oh yeah, and it's open source!

## Features

- **No Code (if you want)**: EasyML ships as a Rails engine. Just mount it in your app and get started.
- **Opinionated Framework**: Provides a structured approach to data and model management, ensuring best practices are followed.
- **Model Lifecycle On Rails**: Want predictions directly from your Rails app? You can do that.
- **Easily Extensible**: Want a model that's not supported? Send a pull request!

## Current and Planned Features

### Models Available

| XGBoost | LightGBM | TensorFlow | PyTorch |
| ------- | -------- | ---------- | ------- |
| ✅      | ❌       | ❌         | ❌      |

### Datasources Available

| S3  | File | Polars | SQL Databases | REST APIs |
| --- | ---- | ------ | ------------- | --------- |
| ✅  | ✅   | ✅     | ❌            | ❌        |

_Note: Features marked with ❌ are part of the roadmap and are not yet implemented._

## Quick Start:

Building a Production pipeline is as easy as 1,2,3!

### 1. Create Your Dataset

```ruby
class MyDataset < EasyML::Data::Dataset
  datasource :s3, s3_bucket: "my-bucket" # Every time the data changes, we'll pull new data
  target "revenue" # What are we trying to predict?
  splitter :date, date_column: "created_at" # How should we partition data into training, test, and validation datasets?
  transforms DataPipeline # Class that manages data transformation, adding new columns, etc.
  preprocessing_steps({
    training: {
      annual_revenue: { median: true, clip: { min: 0, max: 500_000 } }
    }
  }) # If annual revenue is missing, use the median value, after clipping the values into the approved list
end
```

### 2. Create a Model

```ruby
class MyModel < EasyML::Models::XGBoost
  dataset MyDataset
  task :regression # Or classification
  hyperparameters({
    max_depth: 5,
    learning_rate: 0.1,
    objective: "reg:squarederror"
  })
end
```

### 3. Create a Trainer

```ruby
class MyTrainer < EasyML::Trainer
  model MyModel
  evaluator MyMetrics
end

class MyMetrics
  def metric_we_make_money(y_pred, y_true)
    return true if model_makes_money?
    return false if model_lose_money?
  end

  def metric_sales_team_has_enough_leads(y_pred, y_true)
    return false if sales_will_be_sitting_on_their_hands?
  end
end
```

Now you're ready to predict in production!

```ruby
MyTrainer.train # Yay, we did it!
MyTrainer.deploy # Let the production hosts know it's live!
MyTrainer.predict(customer_data: "I am worth a lot of money")
# prediction: true!
```

## Mount The Engine

```ruby
Rails.application.routes.draw do
  mount EasyML::Engine, at: "easy_ml"
end
```

## Data Management

EasyML provides a comprehensive data management system that handles all preprocessing tasks, including splitting data into train, test, and validation sets, and avoiding data leakage. The primary abstraction for data handling is the `Dataset` class, which ensures data is properly managed and prepared for machine learning tasks.

### Preprocessing Features

EasyML offers a variety of preprocessing features to prepare your data for machine learning models. Here's a complete list of available preprocessing steps and examples of when to use them:

- **Mean Imputation**: Replace missing values with the mean of the feature. Use this when you want to maintain the average value of the data.

  ```ruby
  annual_revenue: {
    mean: true
  }
  ```

- **Median Imputation**: Replace missing values with the median of the feature. This is useful when you want to maintain the central tendency of the data without being affected by outliers.

  ```ruby
  annual_revenue: {
    median: true
  }
  ```

- **Forward Fill (ffill)**: Fill missing values with the last observed value. Use this for time series data where the last known value is a reasonable estimate for missing values.

  ```ruby
  created_date: {
    ffill: true
  }
  ```

- **Most Frequent Imputation**: Replace missing values with the most frequently occurring value. This is useful for categorical data where the mode is a reasonable estimate for missing values.

  ```ruby
  loan_purpose: {
    most_frequent: true
  }
  ```

- **Constant Imputation**: Replace missing values with a constant value. Use this when you have a specific value that should be used for missing data.

  ```ruby
  loan_purpose: {
    constant: { fill_value: 'unknown' }
  }
  ```

- **Today Imputation**: Fill missing date values with the current date. Use this for features that should default to the current date.

  ```ruby
  created_date: {
    today: true
  }
  ```

- **One-Hot Encoding**: Convert categorical variables into a set of binary variables. Use this when you have categorical data that needs to be converted into a numerical format for model training.

  ```ruby
  loan_purpose: {
    one_hot: true
  }
  ```

- **Ordinal Encoding**: Convert categorical variables into integer labels. Use this when you have categorical data that can be ordinally encoded.

  ```ruby
  loan_purpose: {
    categorical: {
      ordinal_encoding: true
    }
  }
  ```

### Other Dataset Features

- **Data Splitting**: Automatically split data into train, test, and validation sets using various strategies, such as date-based splitting.
- **Data Synchronization**: Ensure data is synced from its source, such as S3 or local files.
- **Batch Processing**: Process data in batches to handle large datasets efficiently.
- **Null Handling**: Alert and handle null values in datasets to ensure data quality.

## Feature Store

The Feature Store is a powerful component of EasyML that helps you manage, compute, and serve features for your machine learning models. Here's how to use it effectively:

### Setting Up Features

1. Create a `features` directory in your application:

```bash
mkdir app/features
```

2. Create feature classes in this directory. Each feature should include the `EasyML::Features` module:

```ruby
class MyFeature
  include EasyML::Features

  def transform(df, feature)
    # Your feature transformation logic here
  end

  feature name: "My Feature",
          description: "Description of what this feature does"
end
```

### Feature Types and Configurations

#### Simple Transform-Only Features

For features that can be computed using only the input columns:

```ruby
class DidConvert
  include EasyML::Features

  def transform(df, feature)
    df.with_column(
      (Polars.col("rev") > 0).alias("did_convert")
    )
  end

  feature name: "did_convert",
          description: "Boolean indicating if conversion occurred"
end
```

#### Batch Processing Features

For features that require processing large datasets in chunks:

```ruby
class LastConversionTimeFeature
  include EasyML::Features

  def batch(reader, feature)
    # Efficiently query only the company_id column for batching
    # This will create batches of batch_size records (default 1000)
    reader.query(select: ["company_id"], unique: true)["company_id"]
  end

  def fit(reader, feature, options = {})
    batch_start = options.dig(:batch_start)
    batch_end = options.dig(:batch_end)

    # More efficient than is_in for continuous ranges
    df = reader.query(
      filter: Polars.col("company_id").is_between(batch_start, batch_end),
      select: ["id", "company_id", "converted_at", "created_at"],
      sort: ["company_id", "created_at"]
    )

    # For each company, find the last time they converted before each application
    #
    # This value will be cached in the feature store for fast inference retrieval
    df.with_columns([
      Polars.col("converted_at")
        .shift(1)
        .filter(Polars.col("converted_at").is_not_null())
        .over("company_id")
        .alias("last_conversion_time"),

      # Also compute days since last conversion
      (Polars.col("created_at") - Polars.col("last_conversion_time"))
        .dt.days()
        .alias("days_since_last_conversion")
    ])[["id", "last_conversion_time", "days_since_last_conversion"]]
  end

  def transform(df, feature)
    # Pull the pre-computed values from the feature store
    stored_df = feature.query(filter: Polars.col("id").is_in(df["id"]))
    return df if stored_df.empty?

    df.join(stored_df, on: "id", how: "left")
  end

  feature name: "Last Conversion Time",
          description: "Computes the last time a company converted before each application",
          batch_size: 1000,  # Process 1000 companies at a time
          primary_key: "id",
          cache_for: 24.hours  # Cache feature values for 24 hours after running fit
end
```

This example demonstrates several key concepts:

1. **Efficient Batching**: The `batch` method uses the reader to lazily query only the necessary column for batching
1. **Batches Groups Together**: All records with the same `company_id` need to be in the same batch to properly compute the feature, so we create a custom batch (instead of using the primary key `id` column, which would split up companies into different batches)
1. **Column Selection**: Only selects required columns in the reader query
1. **Feature Computation**: Computes multiple related features (last conversion time and days since) in a single pass.
1. **Automatic Feature Store Caching**: The feature store automatically caches feature values returned from the `fit` method

### Performance Optimization

#### Caching During Development

Use `cache_for` to save processing time during development:

```ruby
feature name: "My Feature",
        cache_for: 24.hours # After running fit, this feature will be cached for 24 hours (unless new data is read from datasource, like S3)
```

#### Early Returns

Always implement early returns in your transform method to avoid unnecessary reprocessing:

```ruby
def transform(df, feature)
  return df if df["required_column"].nil?
  # Feature computation logic
end
```

#### Using Reader vs DataFrame

- The Polars `reader` is a lazy reader that allows you to query data incrementally.
- If your feature includes a `batch` method or uses the `batch_size` variable, you will receive a reader instead of a dataframe in the `fit` method

```ruby
def fit(reader, feature)
  df = reader.query(select: ["column1", "column2"])
  # Process only needed columns
end
```

- If you don't have a `batch` method or don't use the `batch_size` variable, you will receive a dataframe in the `fit` method

````ruby
def fit(df, feature)
  # process directly on dataframe
end

- To ensure you get a reader instead of a dataframe, include the `batch` method

```ruby
def batch(reader, feature)
  reader.query(select: ["column1"])["column1"]
end

feature name: "My Feature", batch_size: 1_000
````

### Production Considerations

#### Handling Missing Data

When processing historical data:

1. Check for missing dates:

```ruby
def transform(df, feature)
  missing_dates = feature.store.missing_dates(start_date, end_date)
  return df if missing_dates.empty?

  # Process only missing dates
  process_dates(df, missing_dates)
end
```

### Best Practices

1. Always specify a `primary_key` to allow the feature store to partition your data
1. Use `batch/fit` to process large datasets in batches
1. Use `batch/fit` to allow faster inference feature computation
1. Use transform-only features when all required columns will be available on the inference dataset
1. Use `cache_for` to save processing time during development
1. Only query necessary columns using the reader

## Installation

Install necessary Python dependencies

1. **Install Python dependencies (don't worry, all code is in Ruby, we just call through to Python)**

```bash
pip install wandb optuna
```

1. **Install the gem**:

   ```bash
   gem install easy_ml
   ```

2. **Run the generator to store model versions**:

   ```bash
   rails generate easy_ml:migration
   rails db:create # If this is a new app
   rails db:migrate
   ```

3. Add the `easy_ml` dir to your `.gitignore` — This is where datasets and model files will be downloaded

```
# .gitignore
easy_ml/
```

## Usage

To use EasyML in your Rails application, follow these steps:

1. **Define your preprocessing steps** in a configuration hash. For example:

   ```ruby
   preprocessing_steps = {
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
   ```

2. **Create a dataset** using the `EasyML::Data::Dataset` class, providing necessary configurations such as data source, target, and preprocessing steps.

3. **Train a model** using the `EasyML::Models` module, specifying the model class and configuration.

4. **Deploy the model** by marking it as live and storing it in the configured S3 bucket.

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and the created tag, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

1. Install Appraisals gemfiles:

```bash
bundle exec appraisal install
```

1. Creating a test app:

a. Follow the typical steps
b. Declare an environment variable: `EASY_ML_DEMO_APP=true`, using Figaro, dotenv, or similar to load develoment assets
c. Run `yarn vite dev` in both the `easy_ml` gem and test app directories

1. Building production assets

```bash
bin/vite_build
```

1. Building the new gem version:

```bash
bin/build
```

1. Ensure you run tests against all supported Rails versions

Bug reports and pull requests are welcome on GitHub at https://github.com/[USERNAME]/easy_ml. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [code of conduct](https://github.com/[USERNAME]/easy_ml/blob/main/CODE_OF_CONDUCT.md).

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the EasyML project's codebases, issue trackers, chat rooms, and mailing lists is expected to follow the [code of conduct](https://github.com/[USERNAME]/easy_ml/blob/main/CODE_OF_CONDUCT.md).

## Expected Future Enhancements

- **Support for Additional Models**: Integration with LightGBM, TensorFlow, and PyTorch.
- **Expanded Data Source Support**: Ability to pull data from SQL databases and REST APIs.
- **Enhanced Deployment Options**: More flexible deployment strategies and integration with CI/CD pipelines.
- **Advanced Monitoring and Logging**: Improved tools for monitoring model performance and logging.
- **User Interface Improvements**: Enhanced UI components for managing models and datasets.
