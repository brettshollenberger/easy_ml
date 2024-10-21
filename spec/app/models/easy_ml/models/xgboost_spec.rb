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

    def make_trainer
      dataset = EasyML::Data::Dataset.new(
        {
          verbose: false,
          drop_if_null: ["loan_purpose"],
          drop_cols: %w[business_name state id date],
          datasource: df,
          target: target,
          preprocessing_steps: preprocessing_steps,
          splitter: {
            date: {
              today: today,
              date_col: date_col,
              months_test: months_test,
              months_valid: months_valid
            }
          }
        }
      )
      model = EasyML::Models::XGBoost.new({
                                            name: "My model",
                                            root_dir: root_dir,
                                            task: task,
                                            dataset: dataset,
                                            hyperparameters: {
                                              learning_rate: learning_rate,
                                              max_depth: max_depth,
                                              objective: objective
                                            }
                                          })

      EasyML::Trainer.new(
        model: model,
        dataset: model.dataset,
        tuner: EasyML::Core::Tuner.new(
          n_trials: 1,
          model: model,
          objective: :mean_absolute_error,
          config: {
            learning_rate: { min: 0.01, max: 0.1 },
            n_estimators: { min: 1, max: 100 },
            max_depth: { min: 1, max: 8 }
          }
        )
      )
    end

    def new_df
      Polars::DataFrame.new({
                              business_name: ["Business X"],
                              annual_revenue: [nil],
                              loan_purpose: ["payroll"],
                              state: ["VIRGINIA"],
                              rev: [0],
                              date: "2024-01-01"
                            })
    end

    it "saves and reuses statistics for inference" do
      @time = EST.now
      Timecop.freeze(@time)

      trainer = make_trainer
      trainer.train # Model is now saved
      trainer.model.mark_live

      # Simulate another request, after the model has been marked live
      trainer2 = make_trainer

      df1 = trainer.features(new_df)
      df2 = trainer2.features(new_df)
      df1.columns.each do |col|
        expect(df1[col][0]).to eq(df2[col][0])
      end
      expect(df1["annual_revenue"]).to eq 3_000 # Median revenue
      expect(df1["loan_purpose_payroll"]).to eq 1

      expect(trainer.predict(new_df).first).to be_within(0.001).of(trainer2.predict(new_df).first)
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
