module EasyML
  module Support
    EST = ActiveSupport::TimeZone.new("America/New_York") unless defined?(EST)
  end
end
