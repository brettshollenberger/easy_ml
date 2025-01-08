require "resque/tasks"

task :environment do
  require File.expand_path("config/environment", Rails.root)
end

task "resque:work" => :environment
task "resque:workers" => :environment
