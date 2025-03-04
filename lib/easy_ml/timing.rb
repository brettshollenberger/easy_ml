require "active_support/concern"

module EasyML
  module Timing
    extend ActiveSupport::Concern

    # Handles both instance and class methods
    def self.apply_timing(klass, method_name, prefix: nil, method_type: :instance)
      if klass.respond_to?(method_name) && (klass.is_a?(Module) || !klass.new.respond_to?(method_name))
        method_type = :class
      end

      method_alias = "untimed_#{method_name}"
      target = method_type == :class ? klass.singleton_class : klass

      target.send(:alias_method, method_alias, method_name)
      target.send(:define_method, method_name) do |*args, **kwargs, &block|
        starting = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        result = send(method_alias, *args, **kwargs, &block)
        ending = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        elapsed = ending - starting
        puts "#{method_name} took #{elapsed} seconds"
        # StatsD.measure("#{Rails.env}.#{prefix.present? ? "#{prefix}." : ""}#{method_name}.timing", elapsed)
        result
      end
    end

    class_methods do
      def measure_method_timing(method_name, prefix: nil, method_type: :instance)
        Timing.apply_timing(self, method_name, prefix: prefix, method_type: method_type)
      end
    end
  end
end
