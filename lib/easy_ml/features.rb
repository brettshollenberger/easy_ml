module EasyML::Features
  def fit(reader, feature)
    raise NotImplementedError
  end

  def batch(reader, feature)
    raise NotImplementedError
  end

  def transform(df, feature)
    raise NotImplementedError
  end

  def self.included(base)
    base.extend(ClassMethods)
  end

  module ClassMethods
    def features
      @features ||= []
    end

    def feature(name: nil, description: nil, batch_size: 10_000, primary_key: nil)
      features << {
        name: name,
        description: description,
        batch_size: batch_size,
        primary_key: primary_key,
      }
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

        feature_class.features.each do |feature|
          [namespace, feature[:name]].compact.join("/")
          registry[namespace][feature[:name]] = feature.merge!(
            feature_class: feature_class,
          )
        end
      end

      def list(namespace: nil)
        namespace ? registry[namespace.to_sym] : registry
      end

      def list_flat
        (list.try(:values) || []).flat_map(&:values)
      end

      def find(name, namespace: nil)
        namespace = namespace&.to_sym
        return registry.dig(namespace, name) if namespace

        registry.each_value do |ns_registry|
          if found = ns_registry[name]
            return found
          end
        end
        nil
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
