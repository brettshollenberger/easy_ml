require "zhong"

Zhong.redis = Redis.new(url: ENV.fetch("REDIS_URL") { "redis://localhost:6379/0" })

if %w[zhong:start].include?(ARGV.first)
  Zhong.schedule do
    every 1.hour, "cleanup" do
      EasyML::CleanJob.perform_later
    end
  end
end
