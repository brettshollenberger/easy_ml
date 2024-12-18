require "spec_helper"
require "support/model_spec_helper"
require "support/file_spec_helper"

RSpec.describe EasyML::Splitter do
  include ModelSpecHelper

  let(:today) do
    EasyML::Support::EST.parse("2024-10-01")
  end

  def split_percentage(dataset, split)
    dataset.send(split).count / dataset.data.count.to_f
  end

  describe "Random splitter" do
    let(:dataset) { titanic_dataset }

    it "splits files randomly" do
      mock_s3_download(single_file_dir)
      mock_s3_upload

      dataset.refresh!

      expect(split_percentage(dataset, :train)).to be_within(0.01).of(0.6)
      expect(split_percentage(dataset, :test)).to be_within(0.01).of(0.2)
      expect(split_percentage(dataset, :valid)).to be_within(0.01).of(0.2)
    end

    it "does not include the same row twice across splits" do
      mock_s3_download(single_file_dir)
      mock_s3_upload

      dataset.refresh!

      train_ids = dataset.train["PassengerId"].to_a
      test_ids = dataset.test["PassengerId"].to_a
      valid_ids = dataset.valid["PassengerId"].to_a

      expect(train_ids & test_ids).to be_empty
      expect(train_ids & valid_ids).to be_empty
      expect(test_ids & valid_ids).to be_empty
    end

    it "splits targets" do
      mock_s3_download(single_file_dir)
      mock_s3_upload

      dataset.refresh!
      dataset.columns.find_by(name: "Survived").update(is_target: true)
      dataset.refresh!
      _, ys = dataset.train(split_ys: true)
      expect(ys["Survived"]).to eq dataset.train["Survived"]
    end
  end

  describe "Date splitter" do
    let(:dataset) { loans_dataset }

    it "splits files by date" do
      mock_s3_download(single_file_dir)
      mock_s3_upload

      dataset.refresh!

      expect(dataset.train.count).to be > 0
      expect(dataset.test.count).to be > 0
      expect(dataset.valid.count).to be > 0
      expect(dataset.data.count).to eq(dataset.train.count + dataset.test.count + dataset.valid.count)
    end

    it "respects the date boundaries for splits" do
      mock_s3_download(single_file_dir)
      mock_s3_upload

      dataset.refresh!

      test_start = dataset.splitter.splits[1]
      valid_start = dataset.splitter.splits[0]

      expect(dataset.train(all_columns: true)["date"].max).to be < valid_start
      expect(dataset.valid(all_columns: true)["date"].min).to be >= valid_start
      expect(dataset.valid(all_columns: true)["date"].max).to be < test_start
      expect(dataset.test(all_columns: true)["date"].min).to be >= test_start
    end

    it "splits targets" do
      mock_s3_download(single_file_dir)
      mock_s3_upload

      dataset.refresh!
      dataset.columns.find_by(name: "rev").update(is_target: true)
      dataset.refresh!
      _, ys = dataset.train(split_ys: true)
      expect(ys["rev"]).to eq dataset.train["rev"]
    end
  end
end
