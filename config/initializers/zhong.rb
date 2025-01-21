require "zhong"

Zhong.setup do |config|
  config.logger = Rails.logger
  config.time_zone = "UTC"

  # Use Redis to persist the scheduler state
  config.redis = Redis.new(
    url: ENV.fetch("REDIS_URL") { "redis://localhost:6379/0" },
  )
end

Zhong.schedule do
  every 1.hour, "cleanup" do
    CleanJob.perform_later
  end
end
