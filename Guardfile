guard :rspec, cmd: "bundle exec rspec" do
  # watch(%r{^spec/.+\.rb$}) { |_m| "spec/lib/easy_ml/features_spec.rb" }
  # watch(%r{^lib/(.+)\.rb$}) { |_m| "spec/lib/easy_ml/features_spec.rb" }
  # watch(%r{^app/(.+)\.rb$}) { |_m| "spec/lib/easy_ml/features_spec.rb" }

  watch(%r{^spec/.+\.rb$}) { |_m| "spec/app/models/easy_ml/model_spec.rb" }
  watch(%r{^lib/(.+)\.rb$}) { |_m| "spec/app/models/easy_ml/model_spec.rb" }
  watch(%r{^app/(.+)\.rb$}) { |_m| "spec/app/models/easy_ml/model_spec.rb" }
end
