module EasyML::Transforms
  def self.included(base)
    base.extend(ClassMethods)
  end

  module ClassMethods
    def transforms
      @transforms ||= []
    end

    def transform(method_name, name: nil, description: nil)
      transforms << {
        method: method_name,
        name: name || method_name.to_s.humanize,
        description: description
      }
    end

    def apply_transforms(df)
      new.apply_transforms(df)
    end
  end

  def missing_any?(list1, list2)
    (list1 - list2).any?
  end

  def apply_transforms(df)
    self.class.transforms.reduce(df) do |df, transform|
      send(transform[:method], df)
    end
  end

  class Registry
    class << self
      def register(transform_class, namespace: nil)
        namespace = namespace&.to_sym
        registry[namespace] ||= {}

        transform_class.transforms.each do |transform|
          [namespace, transform[:name]].compact.join("/")
          registry[namespace][transform[:name]] = {
            class: transform_class,
            method: transform[:method],
            description: transform[:description]
          }
        end
      end

      def list(namespace: nil)
        namespace ? registry[namespace.to_sym] : registry
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
