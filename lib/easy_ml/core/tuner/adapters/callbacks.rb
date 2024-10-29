module EasyML
  module Core
    class Tuner
      module Adapters
        module Callbacks
          def self.included(base)
            base.extend(ClassMethods)
            base.instance_variable_set(:@callback_adapters, {})
          end

          module ClassMethods
            def register_callback_adapter(callback_class, adapter_class)
              @callback_adapters ||= {}
              @callback_adapters[callback_class] = adapter_class
            end

            def callback_adapters
              @callback_adapters
            end
          end

          def run_callbacks(type)
            return unless model.callbacks.present?

            model.callbacks.each do |callback|
              adapter_class = self.class.callback_adapters[callback.class]
              next unless adapter_class

              adapter = adapter_class.new(
                model: model,
                x_true: x_true,
                y_true: y_true,
                tune_started_at: tune_started_at
              )

              adapter.public_send(type, self) if adapter.respond_to?(type)
            end
          end

          private

          def tune_started_at
            @tune_started_at ||= Time.current
          end
        end
      end
    end
  end
end
