require "spec_helper"
require "support/model_spec_helper"

RSpec.describe EasyML::RetrainingJob do
  include ModelSpecHelper

  let(:model_name) do
    "My Model"
  end

  before(:each) do
    EasyML::Cleaner.clean
  end

  after(:each) do
    EasyML::Cleaner.clean
  end

  let(:model) do
    loans_model.save
    loans_model
  end

  let(:valid_attributes) do
    {
      model: model,
      frequency: "week",
      at: {
        hour: 2,
        day_of_week: 1,
      },
      active: true,
      metric: "accuracy_score",
      direction: "maximize",
      threshold: 0.85,
      tuner_config: {
        n_trials: 5,
        config: {
          learning_rate: { min: 0.01, max: 0.1 },
          n_estimators: { min: 1, max: 2 },
          max_depth: { min: 1, max: 5 },
        },
      },
    }
  end

  describe "validations" do
    it "requires model" do
      job = described_class.new(valid_attributes.except(:model))
      expect(job).not_to be_valid
      expect(job.errors[:model]).to include("can't be blank")
    end

    it "requires frequency" do
      job = described_class.new(valid_attributes.except(:frequency))
      expect(job).not_to be_valid
      expect(job.errors[:frequency]).to include("can't be blank")
    end

    it "requires at" do
      job = described_class.new(valid_attributes.except(:at))
      expect(job).not_to be_valid
      expect(job.errors[:at]).to include("can't be blank")
    end

    it "validates frequency inclusion" do
      job = described_class.new(valid_attributes.merge(frequency: "invalid"))
      expect(job).not_to be_valid
      expect(job.errors[:frequency]).to include("is not included in the list")
    end

    it "validates at is between 0 and 23" do
      job = described_class.new(valid_attributes.merge(at: { hour: 24, day_of_week: 1 }))
      expect(job).not_to be_valid
      expect(job.errors[:at]).to include("hour must be between 0 and 23")

      job = described_class.new(valid_attributes.merge(at: { hour: -1, day_of_week: 1 }))
      expect(job).not_to be_valid
      expect(job.errors[:at]).to include("hour must be between 0 and 23")
    end

    it "validates model uniqueness" do
      described_class.create(valid_attributes)
      duplicate_job = described_class.new(valid_attributes)

      expect(duplicate_job).not_to be_valid
      expect(duplicate_job.errors[:model]).to include("already has a retraining job")
    end

    it "validates model existence" do
      job = described_class.new(valid_attributes.merge(model: nil))
      expect(job).not_to be_valid
      expect(job.errors[:model]).to include("can't be blank")
    end

    it "is valid when model exists and is in inference state" do
      job = described_class.new(valid_attributes)
      expect(job).to be_valid
    end

    it "requires metric" do
      job = described_class.new(valid_attributes.except(:metric))
      expect(job).not_to be_valid
      expect(job.errors[:metric]).to include("can't be blank")
    end

    it "requires threshold" do
      job = described_class.new(valid_attributes.except(:threshold))
      expect(job).not_to be_valid
      expect(job.errors[:threshold]).to include("can't be blank")
    end

    it "validates at for daily frequency" do
      job = described_class.new(valid_attributes.merge(frequency: "day", at: {}))
      expect(job).not_to be_valid

      job = described_class.new(valid_attributes.merge(frequency: "day", at: { hour: 24 }))
      expect(job).not_to be_valid
      expect(job.errors[:at]).to include("hour must be between 0 and 23")
    end
  end

  describe "associations" do
    let(:job) { described_class.create(valid_attributes) }

    it "has many retraining runs" do
      run = EasyML::RetrainingRun.create!(retraining_job: job, status: "pending", model: job.model)
      expect(job.retraining_runs).to include(run)
    end
  end

  describe "#should_run?" do
    let(:job) { described_class.create(valid_attributes.merge(frequency: frequency, at: at)) }
    let(:at) { { hour: 2, day_of_week: 1, day_of_month: 1 } }
    let(:frequency) { "week" }

    context "when job has never run" do
      let(:frequency) { "week" }

      it "returns true" do
        expect(job.should_run?).to be true
      end
    end

    context "with daily frequency" do
      let(:frequency) { "day" }

      context "when current hour matches at" do
        before do
          allow(Time).to receive(:current).and_return(Time.current.change(hour: at[:hour]))
        end

        it "returns true when last run was yesterday" do
          job.update!(last_run_at: 1.day.ago)
          expect(job.should_run?).to be true
        end

        it "returns false when already run today" do
          job.update(last_run_at: Time.current - 1.hour)
          expect(job.should_run?).to be false
        end
      end

      context "when current hour does not match at" do
        before do
          allow(Time).to receive(:current).and_return(Time.current.change(hour: at[:hour] + 1))
        end

        it "returns false" do
          job.update!(last_run_at: 1.day.ago)
          expect(job.should_run?).to be false
        end
      end
    end

    context "with weekly frequency" do
      let(:sunday_at_2am) { (Time.current.beginning_of_week - 1.day).change(hour: at[:hour]) }

      context "when Sunday at specified hour" do
        before do
          allow(Time).to receive(:current).and_return(sunday_at_2am)
        end

        it "returns true when last run was last week" do
          job.at[:day_of_week] = 0
          job.last_run_at = 1.week.ago
          job.save
          expect(job.should_run?).to be true
        end

        it "returns false when already run this week" do
          job.update!(last_run_at: Time.current - 1.hour)
          expect(job.should_run?).to be false
        end
      end

      context "when not Sunday" do
        before do
          allow(Time).to receive(:current).and_return(sunday_at_2am + 1.day)
        end

        it "returns false" do
          job.at[:day_of_week] = 0
          job.last_run_at = 1.week.ago
          job.save
          expect(job.should_run?).to be false
        end
      end
    end

    context "with monthly frequency" do
      let(:frequency) { "month" }
      let(:first_day_at_2am) { Time.current.beginning_of_month.change(hour: at[:hour]) }

      context "when first day of month at specified hour" do
        before do
          allow(Time).to receive(:current).and_return(first_day_at_2am)
        end

        it "returns true when last run was last month" do
          job.update!(last_run_at: 1.month.ago)
          expect(job.should_run?).to be true
        end

        it "returns false when already run this month" do
          job.update!(last_run_at: Time.current - 1.hour)
          expect(job.should_run?).to be false
        end
      end

      context "when not first day of month" do
        before do
          allow(Time).to receive(:current).and_return(first_day_at_2am + 1.day)
        end

        it "returns false" do
          job.update!(last_run_at: 1.month.ago)
          expect(job.should_run?).to be false
        end
      end
    end
  end

  describe "#should_tune?" do
    let(:job) do
      described_class.create(valid_attributes.merge(
        tuning_enabled: true,
        tuning_frequency: tuning_frequency,
        at: at,
      ))
    end
    let(:at) { { hour: 2, day_of_week: 1, day_of_month: 1 } }
    let(:tuning_frequency) { "week" }

    it "returns false when tuning_frequency is nil" do
      job.update!(tuning_frequency: nil)
      expect(job.should_tune?).to be false
    end

    it "returns true when never tuned before" do
      expect(job.should_tune?).to be true
    end

    context "with weekly tuning frequency" do
      let(:sunday_at_2am) { (Time.current.beginning_of_week - 1.day).change(hour: at[:hour]) }

      before do
        allow(Time).to receive(:current).and_return(sunday_at_2am)
      end

      it "returns true when last tuning was over a week ago" do
        job.update!(last_tuning_at: 2.weeks.ago)
        expect(job.should_tune?).to be true
      end

      it "returns false when last tuning was this week" do
        job.update!(last_tuning_at: 1.hour.ago)
        expect(job.should_tune?).to be false
      end
    end
  end
end
