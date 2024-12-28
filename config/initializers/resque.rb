require 'resque'
Resque.redis = ENV['REDIS_URL'] || 'redis://localhost:6379'

