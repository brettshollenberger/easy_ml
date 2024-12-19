require "spec_helper"
require "support/model_spec_helper"
require "support/file_spec_helper"

RSpec.describe EasyML::Splitters::RandomSplitter do
  include ModelSpecHelper

  let(:dataset) { titanic_dataset }

  def split_percentage(dataset, split)
    dataset.send(split).count / dataset.data.count.to_f
  end

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