# EasyML

EasyML is a Ruby gem designed to simplify the process of building, deploying, and managing the lifecycle of machine learning models within a Ruby on Rails application. It is a plug-and-play, opinionated framework that currently supports XGBoost, with plans to expand support to a variety of models and infrastructures. EasyML aims to make deployment and lifecycle management straightforward and efficient.

## Features

- **Plug-and-Play Architecture**: EasyML is designed to be easily extendable, allowing for the integration of various machine learning models and data sources.
- **Opinionated Framework**: Provides a structured approach to model management, ensuring best practices are followed.
- **Model Lifecycle On Rails**: Seamlessly integrates with Ruby on Rails, allowing simplified deployment of models to production.

## Current and Planned Features

| Feature                   | Status |
| ------------------------- | ------ |
| **Models Available**      |        |
| XGBoost                   | ✅     |
| LightGBM                  | ❌     |
| TensorFlow                | ❌     |
| PyTorch                   | ❌     |
| **Datasources Available** |        |
| S3                        | ✅     |
| File                      | ✅     |
| Polars                    | ✅     |
| SQL Databases             | ❌     |
| REST APIs                 | ❌     |

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
MyTrainer.predict(customer_data: "I am worth a lot of money")
# prediction: true!
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

- **Label Encoding**: Convert categorical variables into integer labels. Use this when you have categorical data that can be ordinally encoded.

  ```ruby
  loan_purpose: {
    categorical: {
      encode_labels: true
    }
  }
  ```

### Other Dataset Features

- **Data Splitting**: Automatically split data into train, test, and validation sets using various strategies, such as date-based splitting.
- **Data Synchronization**: Ensure data is synced from its source, such as S3 or local files.
- **Batch Processing**: Process data in batches to handle large datasets efficiently.
- **Null Handling**: Alert and handle null values in datasets to ensure data quality.

## Installation

1. **Install the gem**:

   ```bash
   gem install easy_ml
   ```

2. **Run the generator to store model versions**:

   ```bash
   rails generate easy_ml:migration
   rails db:migrate
   ```

3. **Configure CarrierWave for S3 storage**:

   Ensure you have CarrierWave configured to use AWS S3. If not, add the following configuration:

   ```ruby
   # config/initializers/carrierwave.rb
   CarrierWave.configure do |config|
     config.fog_provider = 'fog/aws'
     config.fog_credentials = {
       provider: 'AWS',
       aws_access_key_id: ENV['AWS_ACCESS_KEY_ID'],
       aws_secret_access_key: ENV['AWS_SECRET_ACCESS_KEY'],
       region: ENV['AWS_REGION'],
     }
     config.fog_directory = ENV['AWS_S3_BUCKET']
     config.fog_public = false
     config.storage = :fog
   end
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
