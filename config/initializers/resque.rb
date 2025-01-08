require "resque"
require "resque-pool"

gem_path = Gem::Specification.find_by_name("easy_ml").gem_dir
Resque::Pool.configure do |config|
  config.path = File.join(gem_path, "config", "resque-pool.yml")
  puts "Resque pool config: #{config.path}"
end

Resque.redis = ENV["REDIS_URL"] || "redis://localhost:6379"
