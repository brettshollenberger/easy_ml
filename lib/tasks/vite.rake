namespace :vite do
  desc "Build production assets for EasyML gem"
  task :build do
    system("bin/vite_build")
  end
end
