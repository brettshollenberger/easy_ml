module EasyML
  module Data
    require_relative "data/utils"
    require_relative "data/polars_reader"
    require_relative "data/polars_in_memory"
    require_relative "data/synced_directory"
    require_relative "data/splits"
    require_relative "data/polars_column"
    require_relative "data/polars_schema"
    require_relative "data/date_converter"
    require_relative "data/dataset_manager"
  end
end
