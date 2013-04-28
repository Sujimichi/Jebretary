require 'factory_girl'
def rand_no
  (rand*100000).round
end

FactoryGirl.define do
  factory :instance do
    full_path [Rails.root.to_s.split("/"), 'temp_test_dir', 'KSP_test'].flatten.to_json
  end

  factory :campaign do
    name "test"
  end

  factory :craft do 
    name "my_rocket"
  end

end

