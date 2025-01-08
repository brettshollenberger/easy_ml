namespace :easy_ml do
  desc "Start resque-pool with the gem's configuration"
  task :resque_pool do
    require "resque"
    gem_path = Gem::Specification.find_by_name("easy_ml").gem_dir
    config_path = File.join(gem_path, "config", "resque-pool.yml")

    ENV["RESQUE_POOL_CONFIG"] = config_path
    puts "Starting resque-pool with config: #{config_path}"

    exec "bundle exec resque-pool --environment #{ENV["RAILS_ENV"] || "development"} --config #{config_path}"
  end
end
