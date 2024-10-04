module EasyML
  module Data
    class Dataset
      module Splits
        require_relative "splits/split"
        require_relative "splits/file_split"
        require_relative "splits/in_memory_split"
      end
    end
  end
end
