namespace :zhong do
  desc "Run Zhong"
  task start: :environment do
    Zhong.start
  end
end
