module EasyML::Features
  def transform(df, feature)
    raise NotImplementedError
  end

  def self.included(base)
    base.extend(ClassMethods)
    Registry.register(base)
  end

  module ClassMethods
    def features
      @features ||= []
    end

    def feature(**kwargs)
      features << kwargs
    end
  end

  def missing_any?(list1, list2)
    (list1 - list2).any?
  end

  class Registry
    class << self
      def register(feature_class, namespace: nil)
        namespace = namespace&.to_sym
        registry[namespace] ||= {}
        registry[namespace][feature_class] = feature_class
      end

      def list(namespace: nil)
        namespace ? registry[namespace.to_sym] : registry
      end

      def list_flat
        (list.try(:values) || []).flat_map(&:values)
      end

      def find(name)
        list_flat.detect { |feature| feature.name == name }
      end

      def clear
        @registry = {}
      end

      private

      def registry
        @registry ||= {}
      end
    end
  end
end
