<img src="easy_ml.svg" alt="EasyML Logo" style="width: 310px; height: 300px;">

# EasyML

~~You can't do machine learning in Ruby.~~

Deploy models in minutes, not months.

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

### 1. Install EasyML In Your Existing Rails App

```bash
gem install easy_ml
```

```ruby
mount EasyML::Engine, at: "easy_ml"
```

```bash
rails generate easy_ml:migration
bundle exec rake db:migrate
```

Add a `.env` file with the following contents:

```bash
S3_ACCESS_KEY_ID=<your_key>
S3_SECRET_ACCESS_KEY=<your_secret>
WANDB_API_KEY=<your_api_key> # if you want to use Wandb for logging
```

And make sure you run the `easy_ml` queue to process jobs, or run via `docker`

```bash
bundle exec rake resque:workers QUEUE=easy_ml COUNT=5
# or
docker compose up
```

### 2. Create Your Dataset

Navigate to `localhost:3000/easy_ml`, and use the web UI to build your datasource + dataset, or create them in your rails console:

```ruby
datasource = EasyML::Datasource.create(name: "My Datasource", datasource_type: "s3", s3_bucket: "my-bucket", s3_prefix: "my-prefix")
dataset = EasyML::Dataset.create(name: "My Dataset", datasource: datasource)
dataset.refresh # Sync datasource. If you do via web UI, this will happen automatically
```

Once your dataset is created, preprocess your features to remove any nulls and encode string/categorical features. The web UI is your best friend here!

Alternatively, you can do it directly in your console:

```ruby
dataset.columns.find_by(name: "Sex").update({
  preprocessing_steps: {
    training: {
      method: "most_frequent",
      encoding: "one_hot",
      params: {
        categorical_min: 2 # How many instances need to be present to define a category? E.g. If at least 2 rows are "Male", then "Sex_male" is a category.
      }
    }
  }
})
```

### 3. Train a Model

The web UI is always the move! But you can also do it directly in your console:

```ruby
model = EasyML::Model.create(
  model_type: "xgboost",
  task: "classification", # or regression
  objective: "binary:logistic", # or "reg:squarederror"
  dataset: dataset,
  hyperparameters: {
    learning_rate: 0.05,
    max_depth: 8,
    n_estimators: 10,
  },
)
model.train
model.deploy
```

## Running Predictions

There are two ways to run predictions, via ActiveRecord, or via API:

### Using ActiveRecord

Prefer to use `EasyML::Predict` over directly accessing `EasyML::Model`, because:

1. Predict uses a singleton to keep the model `preloaded`, avoiding expensive initializations
2. Predict records predictions in the `predictions` table
3. Predict uses the latest deployed model version, whereas `EasyML::Model` loads the most recent version regardless of deployment status

```ruby
EasyML::Predict.predict(model.slug, {"Age": 30, "Sex": "male"})
```

### Using The API

First, you can use the `describe` API to get a list of accepted inputs

```bash
curl -L 127.0.0.1:3000/easy_ml/api?model=MODEL_SLUG
```

Then, POST your inputs to `localhost:3000/easy_ml/predictions`

```bash
curl --location 'http://127.0.0.1:3000/easy_ml/predictions' \
--X POST \
--header 'Content-Type: application/json' \
--data '{

    "model": "article_traffic",
    "input": {
        "Author": "John Doe",
        "Category": "Banking",
        "Title": "Best Bank Account: Up to 3.46%",
        "Top keyword": "Hidden benefits of high yield savings accounts"
    }
}'
```

You can also pass `type: "predict_proba"` to get probability predictions

## Advanced Techniques

### 1. Create Custom Evaluators

In `app/evaluators`, create a custom evaluator. This will be used during hyperparameter tuning to find the model that maximizes your objectives!

```ruby
class MaximizeRevenue < EasyML::Evaluators::Base
  def direction
    :maximize # or minimize
  end

  def description
    "Maximize revenue based on lead segmentation"
  end

  def self.supports_task?(task)
    task == "classification"
  end

  def evaluate(y_pred: [], y_true: [], x_true: nil, dataset: nil)
    # Your evaluation logic here
  end
end
```

### 2. Using The Feature Store

The Feature Store is a powerful component of EasyML that helps you manage, compute, and serve features for your machine learning models. Here's how to use it effectively:

1. Use `fit` for pre-computing features. This ensures that features are computed only once and stored for future use, including serving features in the online model.

2. Use `transform` to read features from the feature store and decorate the input dataframe with new columns OR to compute features that can be computed using other columns.

### A Simple Feature

For example, a simple feature that computes `FamilySize` based on `NumSiblings` and `NumParents`, can use just the `transform` method:

```ruby
class FamilySizeFeature
  include EasyML::Features

  def transform(df, feature)
    df.with_columns(
      (Polars.col("NumSiblings") + Polars.col("NumParents")).alias("FamilySize")
    )
  end

  feature name: "FamilySize",
          description: "Size of the family"
end
```

### Pre-Computing A Feature

On the other hand, when you need to perform expensive pre-computation of a feature, you can use the `fit` method to store the result for future use, and `transform` to read it out:

```ruby
class ExpensiveFeature
  include EasyML::Features

  def fit(df, feature)
    # expensive computation
    # whatever gets returned from here will be stored in the feature store
  end

  def transform(df, feature)
    # read from feature store using feature.query
    feature_df = feature.query(filter: Polars.col("company_id").is_in(df["company_id"]))

    # Return the original dataframe with the new columns
    df.join(
      feature_df,
      on: "company_id",
      how: "left"
    )
  end

  feature name: "Expensive Feature",
          description: "A feature that takes a long time to compute",
          primary_key: :company_id,
          batch_size: 1_000 # Will split data into jobs of 1000 company_ids
end
```

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

#### Defining Primary Keys & Batching

When you have a primary key, it serves two functions:

1. **Batch Key**: The primary key is used to divide data into batches for efficient processing. The batch size refers to the number of primary keys in each batch. So if you have a regular, monotonically increasing primary key, you can set the batch size to 1_000_000, for example.

However, if your primary key refers to groups of records (e.g. group orders by customer*id), you should consider setting the batch size to a smaller value (e.g. 100 average orders per customer * batch*size of 1_000 customer_ids = 100 * 1_000 = 100_000). Base your batch sizes on real-world data to ensure efficient processing.

2. **Data Partitioning**: If you have a typical, numeric primary key, it will also be used to partition data in the feature store. This can help with efficient look-up during feature serving / the online API.

```ruby
feature name: "Order size by customer",
        description: "Average order size per customer",
        primary_key: :customer_id,
        batch_size: 1_000 # Assuming we have 100 average orders per customer, this creates batches of ~100k records
end
```

### Gotchas

- Your `transform` methods must return the same number of rows as the input dataframe. Your `fit` method can pre-compute any number of rows, but the `transform` method is exclusively used for adding columns.

#### Real World Example

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

## Using the Rails Models

A few helpful methods to help you understand the internal workings of the library:

```ruby
d = EasyML::Dataset.find_by(name: "My Dataset")
d.raw.data # Returns the raw data as a Polars::DataFrame
d.processed.data # Returns the processed data as a Polars::DataFrame
d.processed.data(limit: 1, filter: Polars.col("Id").eq(1), select: ["column1", "column2"]) # You can limit, filter, and select directly on the processed data, which lazily queries the dataset
d.columns # Returns the columns as an array of EasyML::Column
d.refresh # Refreshes the dataset, if necessary
d.refresh! # Forces a refresh of the dataset
```

```ruby
column = d.columns.first
column.raw.data # Returns the raw data as a Polars::DataFrame
column.processed.data # Returns the processed data as a Polars::DataFrame
column.processed.data.filter(Polars.col("Id").eq(1)) # You can run Polars expressions directly
column.processed.data(select: ["otherColumn"])
```

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

## Upgrading From An Earlier Version of EasyML

When upgrading, ensure you run the following commands to update the gem and database schema, in case you're missing any migrations

```
rails g easy_ml:migration # To install missing migrations
bundle exec rake db:create
```

## Contributing

1. Install Appraisals gemfiles:

```bash
bundle exec appraisal install
```

1. Creating a test app:

a. Follow the typical steps
b. Declare an environment variable: `EASY_ML_DEV=true`, using Figaro, dotenv, or similar to load develoment assets
c. Run `bin/vite dev` in both the `easy_ml` gem and test app directories
d. If you don't see assets, it's likely your `EASY_ML_DEV` attribute isn't set! Ensure this is loaded early in your application.rb so it's picked up by the engine — if all else fails, try explicitly running `EASY_ML_DEV=true rails s`

1. Building production assets

```bash
bin/vite_build
```

1. Building the new gem version:

```bash
bin/build
```

1. Adding migrations

Update the migration_generator.rb file to install the new migrations, and run:

```bash
rake easy_ml:create_test_migrations && bundle exec rake db:drop db:create db:migrate
rake easy_ml:annotate_models
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
