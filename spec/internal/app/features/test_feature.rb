class TestFeature
  include EasyML::Features
  feature name: "Test Feature",
          description: "A test feature",
          batch_size: 5000
end
