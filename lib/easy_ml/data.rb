module EasyML
  module Data
    require_relative "data/utils"
    require_relative "data/polars_reader"
    require_relative "data/synced_directory"
    require_relative "data/preprocessor"
    require_relative "data/splits"
    require_relative "data/polars_column"
    require_relative "data/statistics_learner"
    require_relative "data/date_converter"
  end
end
