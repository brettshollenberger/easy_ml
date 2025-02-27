require "spec_helper"
require "support/model_spec_helper"

RSpec.describe EasyML::Deploy do
  include ModelSpecHelper

  let(:day_1_dir) do
    titanic_core_dir
  end

  let(:day_2_dir) do
    titanic_extended_dir
  end

  let(:datasource) do
    EasyML::Datasource.create(
      name: "Titanic Core",
      datasource_type: "s3",
      s3_bucket: "titanic",
    )
  end

  let(:target) { "Survived" }
  let(:dataset_config) do
    {
      name: "Titanic Dataset",
      datasource: datasource,
      splitter_attributes: {
        splitter_type: "random",
      },
    }
  end

  let(:hidden_cols) do
    %w[Name Ticket Cabin]
  end

  let(:dataset) do
    mock_s3_download(day_1_dir)
    mock_s3_upload

    EasyML::Features::Registry.register(FamilySizeFeature)
    EasyML::Dataset.create(**dataset_config).tap do |dataset|
      family_size_feature = EasyML::Feature.create!(
        dataset: dataset,
        feature_class: FamilySizeFeature.to_s,
        name: "Family Size",
      )
      dataset.unlock!
      dataset.refresh
      dataset.columns.find_by(name: target).update(is_target: true)
      dataset.columns.where(name: hidden_cols).update_all(hidden: true)
      dataset.columns.find_by(name: "SibSp").update(preprocessing_steps: {
                                                      training: { method: :median },
                                                    })
      dataset.columns.find_by(name: "Parch").update(preprocessing_steps: {
                                                      training: { method: :median },
                                                    })
      dataset.columns.find_by(name: "Sex").update(preprocessing_steps: {
                                                    training: {
                                                      method: :most_frequent,
                                                      encoding: :one_hot,
                                                      params: {
                                                        categorical_min: 2,
                                                      },
                                                    },
                                                  })
      dataset.columns.find_by(name: "Embarked").update(preprocessing_steps: {
                                                         training: {
                                                           method: :most_frequent,
                                                           encoding: :one_hot,
                                                           params: {
                                                             categorical_min: 2,
                                                           },
                                                         },
                                                       })
      dataset.columns.find_by(name: "Age").update(preprocessing_steps: {
                                                    training: {
                                                      method: :median,
                                                    },
                                                  })
      dataset.refresh
    end
  end

  let(:hyperparameters) do
    {
      learning_rate: 0.05,
      max_depth: 8,
      n_estimators: 1,
      booster: "gbtree",
      objective: "reg:squarederror",
    }
  end

  let(:learning_rate) { 0.05 }
  let(:max_depth) { 8 }
  let(:task) { :regression }
  let(:objective) { "reg:squarederror" }
  let(:model_config) do
    {
      name: "My model",
      slug: "my_model",
      model_type: "xgboost",
      task: task,
      dataset: dataset,
      objective: objective,
      hyperparameters: {
        booster: :gbtree,
        learning_rate: learning_rate,
        max_depth: max_depth,
        objective: objective,
        n_estimators: 1,
      },
    }
  end

  let(:model) do
    EasyML::Model.new(model_config)
  end

  before(:each) do
    EasyML::Cleaner.clean
  end

  after(:each) do
    EasyML::Cleaner.clean
  end

  def incr_time
    @time += 1.second
  end

  describe "#deploy" do
    it "uses deployed version for prediction" do
      mock_s3_upload
      model.unlock!

      @time = EasyML::Support::EST.now
      Timecop.freeze(@time)

      model.save
      model.unlock!
      model.train(async: false)
      model.deploy(async: false)
      model_v1 = model.current_version

      Timecop.freeze(@time + 2.hours)

      x_test, y_valid = model.dataset.processed.test(split_ys: true)
      y_valid["Survived"]
      preds_v1 = Polars::Series.new(model.predict(x_test))

      # Historical features are still queryable
      expect(model.current_version.dataset.features.first.query.shape).to eq([500, 2])

      live_predictions = model.current_version.predict(x_test)
      expect(live_predictions.sum).to be_within(0.01).of(preds_v1.sum)

      # Change dataset configuration
      model.dataset.columns.where(name: "Age").update_all(hidden: true)
      model.dataset.refresh

      # Re-train
      y_valid = y_valid["Survived"]
      randomize_hypers(model) do
        pos_cases = y_valid[y_valid == 1].count
        neg_cases = y_valid[y_valid == 0].count
        [pos_cases, neg_cases]
      end
      model.train(async: false)
      model.save
      model_v2 = model
      model_v1.reload

      # retrained model_file is distinct from v1 model_file
      expect(model_v2.model_file.filename).to_not eq(model_v1.model_file.filename)

      retrain_preds = Polars::Series.new(model_v2.predict(x_test))
      expect(retrain_preds.sum).to_not eq(preds_v1.sum)

      # The v1 model dataset configuration is NOT the same as the current model dataset
      expect(model_v2.dataset.train.columns).to_not include("Age")
      expect(model_v1.dataset.train.columns).to include("Age")

      expect(model_v2.current_version.model_file.filename).to eq(model_v1.model_file.filename)
      live_predictions = model_v2.current_version.predict(x_test)
      expect(live_predictions.sum).to be_within(0.01).of(preds_v1.sum) # Even though we use "v2" model to load the snapshot, the latest LIVE snapshot is v1

      model.deploy(async: false)
      live_predictions = model.reload.current_version.predict(x_test)
      expect(live_predictions.sum).to be_within(0.01).of(retrain_preds.sum)

      raw_input = {
        "Pclass" => 1,
        "Sex" => "male",
        "SibSp" => 0,
        "Parch" => 1,
        "Fare" => 100,
        "Embarked" => "C",
      }
      preds = EasyML::Predict.predict("my_model", raw_input)

      prediction = EasyML::Prediction.last
      expect(prediction.prediction_value).to be_between(0, 1)
      expect(prediction.normalized_input.dig("Sex_male")).to eq true
      expect(prediction.normalized_input.dig("FamilySize")).to eq 1 # It saves the computed features
      expect(prediction.prediction_type).to eq "regression"
      expect(prediction.raw_input).to eq(raw_input)
      # It records which version of the model was used
      expect(prediction.model_history.id).to eq model.current_version.id
    end

    it "uses historical dataset when running predictions" do
      mock_s3_upload

      @time = EasyML::Support::EST.now
      Timecop.freeze(@time)

      model.save
      model.train(async: false)

      # When model1 gets deployed, we want to have a copy of its file!
      # We're mocking the download from s3...
      #
      @mock_s3_location = SPEC_ROOT.join("saved_file.json")
      FileUtils.rm(@mock_s3_location) if File.exist?(@mock_s3_location)
      FileUtils.cp(model.model_file.full_path, @mock_s3_location)

      model.deploy(async: false)
      model_v1 = model.current_version

      def extract_timestamp(dir)
        EasyML::Support::UTC.parse(dir.gsub(/\D/, "")).in_time_zone(EST)
      end

      expect(extract_timestamp(model_v1.dataset.raw.dir)).to eq(EasyML::Support::EST.parse("2024-01-01"))
      # Creates a new folder for the next dataset version
      expect(extract_timestamp(model_v1.dataset.raw.dir)).to be < extract_timestamp(model.dataset.raw.dir)
      expect(extract_timestamp(model_v1.dataset.processed.dir)).to be < extract_timestamp(model.dataset.processed.dir)

      Timecop.freeze(@time + 2.hours)

      x_test, y_valid = model.dataset.processed.test(split_ys: true)
      y_valid["Survived"]
      preds_v1 = Polars::Series.new(model.predict(x_test))

      live_predictions = model.current_version.predict(x_test)
      expect(live_predictions.sum).to be_within(0.01).of(preds_v1.sum)

      # By default, we read from the directory with the name provided,
      # so this will switch us to using a bigger dataset
      datasource.name = "Titanic Extended"
      datasource.save
      mock_s3_download(day_2_dir) # Download a DIFFERENT version of the dataset

      # Change dataset configuration
      model.dataset.columns.where(name: "Age").update_all(hidden: true)
      model.dataset.refresh! # Requires a full refresh! because we changed our source

      y_valid = y_valid["Survived"]
      randomize_hypers(model) do
        pos_cases = y_valid[y_valid == 1].count
        neg_cases = y_valid[y_valid == 0].count
        [pos_cases, neg_cases]
      end
      model.train(async: false)
      model.save
      model_v2 = model
      model_v1.reload

      expect(model_v1.dataset.data.count).to eq 500
      expect(model.dataset.data.count).to eq 891

      # Statistics are kept separate
      expect(model_v1.dataset.statistics.dig("raw", "Survived", "num_rows")).to eq 500
      expect(model.dataset.statistics.dig("raw", "Survived", "num_rows")).to eq 891

      # retrained model_file is distinct from v1 model_file
      expect(model_v2.model_file.filename).to_not eq(model_v1.model_file.filename)

      retrain_preds = Polars::Series.new(model_v2.predict(x_test))
      expect(retrain_preds.sum).to_not eq(preds_v1.sum)

      # The v1 model dataset configuration is NOT the same as the current model dataset
      expect(model_v2.dataset.train.columns).to_not include("Age")
      expect(model_v1.dataset.train.columns).to include("Age")

      expect(model_v2.current_version.model_file.filename).to eq(model_v1.model_file.filename)
      live_predictions = model_v2.current_version.predict(x_test)
      expect(live_predictions.sum).to be_within(0.01).of(preds_v1.sum) # Even though we use "v2" model to load the snapshot, the latest LIVE snapshot is v1

      model.deploy(async: false) # Now the latest snapshot becomes v2
      live_predictions = model.reload.current_version.predict(x_test)
      expect(live_predictions.sum).to be_within(0.01).of(retrain_preds.sum)
      expect(model.current_version.dataset.data.count).to eq 891
    end

    it "downloads the old splits from S3 if they aren't present locally" do
      FileUtils.rm_rf(SPEC_ROOT.join("backups"))

      mock_s3_upload

      @time = EasyML::Support::EST.parse("2024-01-01")
      Timecop.freeze(@time)

      model.save
      model.train(async: false)

      Timecop.freeze(EasyML::Support::EST.parse("2024-02-02"))

      model.deploy(async: false)
      model_v1 = model.current_version

      def extract_timestamp(dir)
        EasyML::Support::UTC.parse(dir.gsub(/\D/, "")).in_time_zone(EST)
      end

      expect(extract_timestamp(model_v1.dataset.raw.dir)).to eq(EasyML::Support::EST.parse("2024-01-01"))
      # Creates a new folder for the next dataset version
      expect(extract_timestamp(model_v1.dataset.raw.dir)).to be < extract_timestamp(model.dataset.raw.dir)
      expect(extract_timestamp(model_v1.dataset.processed.dir)).to be < extract_timestamp(model.dataset.processed.dir)

      Timecop.freeze(@time + 2.hours)

      x_test, y_valid = model.dataset.processed.test(split_ys: true)
      y_valid["Survived"]
      preds_v1 = Polars::Series.new(model.predict(x_test))

      live_predictions = model.current_version.predict(x_test)
      expect(live_predictions.sum).to be_within(0.01).of(preds_v1.sum)

      # By default, we read from the directory with the name provided,
      # so this will switch us to using a bigger dataset
      datasource.name = "Titanic Extended"
      datasource.save
      mock_s3_download(day_2_dir) # Download a DIFFERENT version of the dataset

      # Change dataset configuration
      model.dataset.columns.where(name: "Age").update_all(hidden: true)
      model.dataset.refresh! # Requires a full refresh! because we changed our source

      randomize_hypers(model)
      model.save
      model.train(async: false)
      model_v2 = model
      model_v1.reload

      expect(model_v1.dataset.data.count).to eq 500
      expect(model.dataset.data.count).to eq 891

      # Statistics are kept separate
      expect(model_v1.dataset.statistics.dig("raw", "Survived", "num_rows")).to eq 500
      expect(model.dataset.statistics.dig("raw", "Survived", "num_rows")).to eq 891

      # retrained model_file is distinct from v1 model_file
      expect(model_v2.model_file.filename).to_not eq(model_v1.model_file.filename)

      retrain_preds = Polars::Series.new(model_v2.predict(x_test))
      expect(retrain_preds.sum).to_not eq(preds_v1.sum)

      # The v1 model dataset configuration is NOT the same as the current model dataset
      expect(model_v2.dataset.train.columns).to_not include("Age")
      expect(model_v1.dataset.train.columns).to include("Age")

      expect(model_v2.current_version.model_file.filename).to eq(model_v1.model_file.filename)
      live_predictions = model_v2.current_version.predict(x_test)
      expect(live_predictions.sum).to be_within(0.01).of(preds_v1.sum) # Even though we use "v2" model to load the snapshot, the latest LIVE snapshot is v1

      FileUtils.mkdir_p(SPEC_ROOT.join("backups/datasets"))
      FileUtils.mkdir_p(SPEC_ROOT.join("backups/models"))
      FileUtils.mv(model_v1.dataset.root_dir, SPEC_ROOT.join("backups/datasets")) # Move the dataset, so we can mock s3 download

      # Since the v1 model is no longer live, we've deleted the model file... we need to expect it'll be requested from s3 too
      FileUtils.mv(model_v1.model_file.full_path, SPEC_ROOT.join("backups/models"))

      model.deploy(async: false) # Now the latest snapshot becomes v2

      expect(model_v1.model_file).to receive(:download) do
        FileUtils.mv(
          Dir.glob(SPEC_ROOT.join("backups/models/*.json")).first,
          model_v1.model_file.full_path
        )
      end

      model_v2 = model.current_version
      preds_v2 = model_v2.predict(x_test)

      expect(model_v1.dataset.processed).to receive(:download) do
        FileUtils.mv(
          SPEC_ROOT.join("backups/datasets/#{model_v1.dataset.version}"),
          model_v1.dataset.root_dir
        )
      end

      # Both models can still predict
      expect(model_v1.predict(x_test).sum.round(2)).to eq preds_v1.sum.round(2)
      expect(model_v2.predict(x_test).sum.round(2)).to eq preds_v2.sum.round(2)

      FileUtils.rm_rf(SPEC_ROOT.join("backups"))
    end

    it "re-uses existing deploy when deploy has been previously run" do
      FileUtils.rm_rf(SPEC_ROOT.join("backups/models"))

      mock_s3_upload

      @time = EasyML::Support::EST.now
      Timecop.freeze(@time)

      model.save
      model.train(async: false)
      run = model.last_run

      deploy = EasyML::Deploy.create!(
        model: model,
        retraining_run: run,
      )
      deploy.deploy(async: false)
      model_v1 = model.current_version
      expect(deploy.model_version).to eq model_v1
      expect(deploy.retraining_run).to eq run
      expect(deploy.model_file).to eq run.model_file

      Timecop.freeze(@time + 2.hours)
      x_test, y_valid = model.dataset.processed.test(split_ys: true)
      y_valid["Survived"]
      expected_preds_v1 = Polars::Series.new(model.predict(x_test))

      preds_v1 = model.current_version.predict(x_test)
      expect(preds_v1.sum).to be_within(0.01).of(expected_preds_v1.sum)

      # Change dataset configuration
      model.dataset.columns.where(name: "Age").update_all(hidden: true)
      model.dataset.refresh

      # Re-train
      y_valid = y_valid["Survived"]
      randomize_hypers(model) do
        pos_cases = y_valid[y_valid == 1].count
        neg_cases = y_valid[y_valid == 0].count
        [pos_cases, neg_cases]
      end
      model.train(async: false)
      model.save
      run2 = model.last_run
      model_v2 = model
      model_v1.reload

      # retrained model_file is distinct from v1 model_file
      expect(model_v2.model_file.filename).to_not eq(model_v1.model_file.filename)

      retrain_preds = Polars::Series.new(model_v2.predict(x_test))
      expect(retrain_preds.sum).to_not eq(preds_v1.sum)

      # The v1 model dataset configuration is NOT the same as the current model dataset
      expect(model_v2.dataset.train.columns).to_not include("Age")
      expect(model_v1.dataset.train.columns).to include("Age")

      expect(model_v2.current_version.model_file.filename).to eq(model_v1.model_file.filename)
      preds_v2 = model_v2.inference_version.predict(x_test)
      expect(preds_v2.sum).to be_within(0.01).of(preds_v1.sum) # Even though we use "v2" model to load the snapshot, the latest LIVE snapshot is v1

      FileUtils.mkdir_p(SPEC_ROOT.join("backups/models"))
      FileUtils.cp(model_v1.model_file.full_path, SPEC_ROOT.join("backups/models"))
      deploy = EasyML::Deploy.create!(
        model: model,
        retraining_run: run2,
      )
      deploy.deploy(async: false)
      model_v2 = model.current_version
      expect(deploy.model_file.id).to eq run2.model_file.id
      expect(model_v2.model_file.id).to eq run2.model_file.id

      preds_v2 = model.reload.inference_version.predict(x_test)
      expect(preds_v2.sum).to be_within(0.01).of(retrain_preds.sum)

      # Re-deploy previous model (from previous run)
      # Does not create a new model_file, version, etc
      deploy = EasyML::Deploy.create!(
        model: model,
        retraining_run: run,
      )
      EasyML::Cleaner.clean # Before deploying, clean the environment (which wipes the old file)
      deploy.deploy(async: false)
      model_v3 = model.current_version

      expect(model_v3.model_file.id).to eq model_v1.model_file.id
      expect(deploy.model_version).to eq model_v1
      expect(model_v3).to eq model_v1

      # Re-deployed model will download the file from s3, mock this
      expect_any_instance_of(EasyML::ModelFile).to receive(:download) do |synced_file|
        FileUtils.mkdir_p(model_v1.model_file.root_dir)
        FileUtils.mv(Dir.glob(SPEC_ROOT.join("backups/models/*.json")).first, model_v1.model_file.full_path)
      end
      preds_v3 = model.reload.inference_version.predict(x_test)
      expect(preds_v3.sum).to be_within(0.01).of(expected_preds_v1.sum)

      FileUtils.rm_rf(SPEC_ROOT.join("backups/models"))
    ensure
      deploy.unlock! if deploy
    end
  end
end
