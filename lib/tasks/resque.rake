require 'resque'

namespace :resque do
  desc "Start a Resque worker"
  task :work => :environment do
    worker_count = ENV.fetch('WORKER_COUNT', 1).to_i
    worker_count.times do
      fork { exec "QUEUE=* rake resque:work" }
    end
    Process.waitall
  end
end

