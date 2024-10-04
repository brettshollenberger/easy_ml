module EasyML
  class Hyperparameters
    include GlueGun::DSL

    attribute :learning_rate, :float, default: 0.01
    attribute :max_iterations, :integer, default: 100
    attribute :batch_size, :integer, default: 32
    attribute :regularization, :float, default: 0.0001

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
