module EasyML::Features
  def fit(reader, feature)
  end

  def batch(reader, feature)
  end

  def transform(df, feature)
  end

  def self.included(base)
    base.extend(ClassMethods)
  end

  module ClassMethods
    def features
      @features ||= []
    end

    def feature(method_name, name: nil, description: nil)
      features << {
        method: method_name,
        name: name || method_name.to_s.humanize,
        description: description,
      }
    end

    def apply_features(df)
      new.apply_features(df)
    end
  end

  def missing_any?(list1, list2)
    (list1 - list2).any?
  end

  def apply_features(df)
    self.class.features.reduce(df) do |df, feature|
      send(feature[:method], df)
    end
  end

  class Registry
    class << self
      def register(feature_class, namespace: nil)
        namespace = namespace&.to_sym
        registry[namespace] ||= {}

        feature_class.features.each do |feature|
          [namespace, feature[:name]].compact.join("/")
          registry[namespace][feature[:name]] = {
            feature_class: feature_class,
            name: feature[:name],
            feature_method: feature[:method],
            description: feature[:description],
          }
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
