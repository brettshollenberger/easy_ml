require "spec_helper"
require "support/model_spec_helper"

RSpec.describe EasyML::Models::XGBoost do
  let(:model_class) do
    EasyML::Models::XGBoost
  end
  include ModelSpecHelper

  describe "#load" do
    it "loads the model from a file" do
      model.name = "My Model" # Model name + version must be unique
      model.metrics = ["mean_absolute_error"]
      model.fit
      model.save
      expect(model.ml_model).to eq "xg_boost"

      loaded_model = EasyML::Models::XGBoost.find(model.id)
      loaded_model.load

      expect(loaded_model.predict(dataset.test(split_ys: true).first)).to eq(model.predict(dataset.test(split_ys: true).first))
    end
  end

  describe "#mark_live" do
    it "marks all other models of the same name as is_live: false, and sets is_live: true to itself" do
      @time = EST.now
      Timecop.freeze(@time)

      model1 = build_model(name: "Test Model", is_live: true)
      model2 = build_model(name: "Test Model", is_live: false)
      model3 = build_model(name: "Test Model", is_live: false)
      other_model = build_model(name: "Other Model", is_live: true)

      model3.mark_live

      expect(model1.reload.is_live).to be false
      expect(model2.reload.is_live).to be false
      expect(model3.reload.is_live).to be true
      expect(other_model.reload.is_live).to be true
    end

    it "saves and reuses statistics for inference", :focus do
      @time = EST.now
      Timecop.freeze(@time)

      model1 = build_model(name: "Test Model", is_live: true)
      binding.pry
      model2 = build_model(name: "Test Model", is_live: false)
      model3 = build_model(name: "Test Model", is_live: false)
      other_model = build_model(name: "Other Model", is_live: true)

      model3.mark_live

      expect(model1.reload.is_live).to be false
      expect(model2.reload.is_live).to be false
      expect(model3.reload.is_live).to be true
      expect(other_model.reload.is_live).to be true
    end
  end

  describe "#cleanup" do
    it "keeps the live model, deletes the oldest version when training, and retains up to 5 versions per model name" do
      @time = EST.now
      Timecop.freeze(@time)
      # Create test models
      live_model_x = build_model(name: "Model X", is_live: true, created_at: 1.year.ago, dataset: dataset,
                                 metrics: %w[mean_absolute_error])

      recent_models = 7.times.map do |i|
        build_model(name: "Model X", created_at: (6 - i).days.ago)
      end

      old_versions_x = recent_models[0..2]
      recent_versions_x = recent_models[3..-1]

      expect(File).to exist(live_model_x.file.path)
      old_versions_x.each do |old_version|
        expect(File).to_not exist(old_version.file.path)
      end
      recent_versions_x.each.with_index do |recent_version, idx|
        puts "version #{idx + 1} still exist?"
        expect(File).to exist(recent_version.file.path)
      end

      # Create models with a different name
      build_model(name: "Model Y", is_live: true, created_at: 1.year.ago)
      recent_y = 7.times.map do |i|
        build_model(name: "Model Y", created_at: (6 - i).days.ago)
      end

      old_versions_y = recent_y[0..2]
      recent_versions_y = recent_y[3..-1]

      # Simulate training a new model X
      build_model(name: "Model X")

      # add least recent x to old versions x
      old_versions_x << recent_versions_x.shift
      expect(old_versions_x.count).to eq 4
      old_versions_x.each do |old_version|
        expect(File).to_not exist(old_version.file.path)
      end
      recent_versions_x.each do |recent_version|
        expect(File).to exist(recent_version.file.path)
      end

      old_versions_y.each do |old_version|
        expect(File).to_not exist(old_version.file.path)
      end
      recent_versions_y.each do |recent_version|
        expect(File).to exist(recent_version.file.path)
      end

      live_model_x.cleanup!
    end
  end
end
