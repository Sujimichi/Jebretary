# This file is copied to spec/ when you run 'rails generate rspec:install'
ENV["RAILS_ENV"] ||= 'test'
require File.expand_path("../../config/environment", __FILE__)
require 'rspec/rails'
require 'rspec/autorun'

# Requires supporting ruby files with custom matchers and macros, etc,
# in spec/support/ and its subdirectories.
Dir[Rails.root.join("spec/support/**/*.rb")].each {|f| require f}

RSpec.configure do |config|
  # ## Mock Framework
  #
  # If you prefer to use mocha, flexmock or RR, uncomment the appropriate line:
  #
  # config.mock_with :mocha
  # config.mock_with :flexmock
  # config.mock_with :rr

  # Remove this line if you're not using ActiveRecord or ActiveRecord fixtures
  config.fixture_path = "#{::Rails.root}/spec/fixtures"

  # If you're not using ActiveRecord, or you'd prefer not to run each of your
  # examples within a transaction, remove the following line or assign false
  # instead of true.
  config.use_transactional_fixtures = true

  # If true, the base class of anonymous controllers will be inferred
  # automatically. This will be the default behavior in future versions of
  # rspec-rails.
  config.infer_base_class_for_anonymous_controllers = false

  # Run specs in random order to surface order dependencies. If you find an
  # order dependency and want to debug it, you can fix the order by providing
  # the seed, which is printed after each run.
  #     --seed 1234
  config.order = "random"
end

def set_test_dir
  FileUtils.rm_rf "temp_test_dir"
  Dir.mkdir "temp_test_dir"
  Dir.chdir "temp_test_dir"
  Dir.chdir Rails.root      
end

def set_basic_mock_KSP_dir
  FileUtils.rm_rf "KSP_test"
  Dir.mkdir "KSP_test"
  Dir.chdir "KSP_test"
  Dir.mkdir "saves"
  Dir.chdir "saves"  
  Dir.chdir Rails.root
end

def make_sample_data
  cur_dir = Dir.getwd
  File.open("quicksave.sfs", 'w') {|f| f.write("some test data") }
  File.open("persistent.sfs", 'w') {|f| f.write("some test data") }
  Dir.mkdir("Ships")
  Dir.chdir("Ships")
  Dir.mkdir("VAB")
  Dir.mkdir("SPH")
  Dir.chdir("VAB")
  File.open("my_rocket.craft", 'w') {|f| f.write("some test data") }
  File.open("my_other_rocket.craft", 'w') {|f| f.write("some test data") }
  Dir.chdir('..')
  Dir.chdir('SPH')
  File.open("my_rocket_car.craft", 'w') {|f| f.write("some test data") }
  Dir.chdir(cur_dir)
end

def make_new_craft_in campaign = nil, c_type = "VAB", name = "some_rocket"
  return false unless 
  Dir.chdir campaign.path
  Dir.chdir("Ships/#{c_type}")
  File.open("#{name}.craft", 'w') {|f| f.write("some test data") }
end


def verify_craft_for_campaign
  @campaign.create_repo      
  @campaign.verify_craft
end

def commit_craft_in_campaign
  @campaign.reload.craft.each{|c| c.commit}
end

def change_craft_contents craft, new_content = "this is some different file data"
  cur_dir = Dir.getwd
  Dir.chdir(craft.craft_type.upcase)
  File.open("#{craft.name}.craft", 'w') {|f| f.write(new_content) }
  Dir.chdir(cur_dir)
end

def in_test_dir &blk
  d = Dir.getwd
  Dir.chdir "#{Rails.root}/temp_test_dir"
  yield
  Dir.chdir d
end

def set_up_sample_data campaign_name = "test_campaign"
  create_sample_data campaign_name
  @instance = FactoryGirl.create(:instance)
  @campaign = FactoryGirl.create(:campaign, :name => campaign_name, :instance_id => @instance.id)
  Dir.chdir @campaign.path
  make_sample_data
  @campaign
end

def create_sample_data campaign_name = "test_campaign", args = {:reset => true}
  if args[:reset]
    set_test_dir
    in_test_dir { set_basic_mock_KSP_dir }
  end
  in_test_dir do 
    Dir.chdir("KSP_test/saves")
    FileUtils.rm_rf(campaign_name)
    Dir.mkdir(campaign_name)
  end
end

def contain string
  be_include(string)
end


