module EasyML
  class Hyperparameters
    include GlueGun::DSL

    define_attr :learning_rate, default: 0.01
    define_attr :max_iterations, default: 100
    define_attr :batch_size, default: 32
    define_attr :regularization, default: 0.0001

    def initialize(**kwargs)
      super
    end

    def to_h
      self.class.send(:attrs).each_with_object({}) do |attr, hash|
        hash[attr.name] = send(attr.name)
      end
    end

    def merge(other)
      return self if other.nil?

      other_hash = other.is_a?(Hyperparameters) ? other.to_h : other
      merged_hash = to_h.merge(other_hash)
      self.class.new(**merged_hash)
    end

    def [](key)
      send(key) if respond_to?(key)
    end

    def []=(key, value)
      send("#{key}=", value) if respond_to?("#{key}=")
    end
  end
end
