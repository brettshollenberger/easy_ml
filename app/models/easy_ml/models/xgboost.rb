require_relative "../model"

module EasyML
  module Models
    class XGBoost < EasyML::Model
      include EasyML::Core::Models::XGBoostCore
    end
  end
end
