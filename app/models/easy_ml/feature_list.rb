module EasyML
  module FeatureList
    def feature_list
      self
    end

    def dataset
      proxy_association.owner
    end

    def computed_column_names
      flat_map(&:computes_columns).uniq
    end
  end
end
