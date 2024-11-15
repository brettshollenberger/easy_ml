module EasyML
  module Concerns
    module FullyReload
      extend ActiveSupport::Concern
      def fully_reload
        base_vars = self.class.new.instance_variables
        dirty_vars = (instance_variables - base_vars)
        dirty_vars.each { |ivar| remove_instance_variable(ivar) }
        reload
      end
    end
  end
end
