module EasyML
  module ErrorEnhancer
    def self.prepended(base)
      base.instance_methods(false).each do |method|
        wrap_method(base, method)
      end
    end

    def self.wrap_method(klass, method)
      original_method = klass.instance_method(method)

      klass.define_method(method) do |*args, &block|
        original_method.bind(self).call(*args, &block)
      rescue TypeError => e
        raise_custom_error(e, caller_locations, method)
      rescue StandardError => e
        raise_custom_error(e, caller_locations, method)
      end
    end

    private

    def raise_custom_error(error, stack, method)
      message = <<~ERROR_MESSAGE
        Error: #{error.message}
        Class: #{self.class.name}
        Method: #{method}
        File: #{stack.first.path}:#{stack.first.lineno}

        Original Backtrace:
        #{error.backtrace.join("\n")}
      ERROR_MESSAGE

      raise error.class, message
    end
  end
end
