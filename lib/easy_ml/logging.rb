module EasyML
  module Logging
    def self.included(base)
      base.extend(ClassMethods)
    end

    module ClassMethods
      def log_method(method_name, message, verbose: false)
        original_method = instance_method(method_name)
        define_method(method_name) do |*args, **kwargs, &block|
          log_message(message, verbose: verbose)
          result = original_method.bind(self).call(*args, **kwargs, &block)
          result
        end
      end
    end

    def log_message(message, verbose: false)
      if verbose
        log_verbose(message)
      else
        puts message
      end
    end

    def log_verbose(message)
      puts message if @verbose
    end

    def log_warning(message)
      puts "\e[33mWARNING: #{message}\e[0m"
    end

    def log_info(message)
      puts "\e[34mINFO: #{message}\e[0m"
    end
  end
end
