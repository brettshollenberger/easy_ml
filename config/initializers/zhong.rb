require "zhong"

Zhong.redis = Redis.new(url: ENV.fetch("REDIS_URL") { "redis://localhost:6379/0" })
Zhong.schedule do
  every 1.hour, "cleanup" do
    CleanJob.perform_later
  end
end
