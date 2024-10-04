guard :rspec, cmd: "bundle exec rspec" do
  watch(%r{^spec/.+_spec\.rb$}) { |_m| "spec/lib/easy_ml/data/dataset_spec.rb" }
  watch(%r{^lib/(.+)\.rb$}) { |_m| "spec/lib/easy_ml/data/dataset_spec.rb" }
end
