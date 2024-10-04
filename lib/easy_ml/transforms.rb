module EasyML::Transforms
  def self.included(base)
    base.extend(ClassMethods)
  end

  module ClassMethods
    def transforms
      @transforms ||= []
    end

    def transform(method_name)
      transforms << method_name
    end

    def apply_transforms(df)
      new.apply_transforms(df)
    end
  end

  def missing_any?(list1, list2)
    (list1 - list2).any?
  end

  def apply_transforms(df)
    self.class.transforms.reduce(df) do |df, transform_method|
      send(transform_method, df)
    end
  end
end
