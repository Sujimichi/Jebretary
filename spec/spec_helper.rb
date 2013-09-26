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
  Dir.chdir Rails.root      
  FileUtils.rm_rf "temp_test_dir"
  Dir.mkdir "temp_test_dir"
  #Dir.chdir "temp_test_dir"

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
  Dir.chdir File.join([craft.campaign.path, "Ships", craft.craft_type.upcase])
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
  make_campaign_dir campaign_name
  @instance = FactoryGirl.create(:instance)
  @campaign = FactoryGirl.create(:campaign, :name => campaign_name, :instance_id => @instance.id)
  Dir.chdir @campaign.path
  make_sample_data
  @campaign
end

def make_campaign_dir campaign_name = "test_campaign", args = {:reset => true}
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


class TestCraft
  attr_accessor :craft, :campaign, :file

  def initialize campaign_id, name = "test_craft", craft_type = :vab
    @campaign = Campaign.find(campaign_id)
    @file = File.join([@campaign.path, "Ships", craft_type.to_s.upcase, "#{name}.craft"])
    File.open(@file, 'w'){|f| f.write("A Craft")}
    System.process
    @craft = Craft.where(:name => name, :campaign_id => @campaign.id).first
  end

  def rand_edit
    data = File.open(@file, 'r'){|f| f.readlines}
    data << "fooblah#{rand}"
    File.open(@file, 'w'){|f| f.write data.join}
  end 

  def edit_p_file
    edit_file type = :persistent
  end
  def edit_s_file
    edit_file type = :quicksave
  end

  def edit_file type = :persistent
    save_file = (type.eql?(:persistent) ? 'persistent' : 'quicksave') << '.sfs'
    path = File.expand_path(File.join([@campaign.path, save_file]))
    file_data = File.open(path, 'r'){|f| f.readlines}
    e_line = file_data.select{|line| line.include?("CanQuickSave")}.first
    i = file_data.index(e_line)
    file_data[i] = file_data[i].sub("True", "True#{(10*rand).round}")
    File.open(path, 'w'){|f| f.write file_data.join}
  end

  def test
    threads= []

    rand_edit
    edit_p_file  

    threads << Thread.new{
      #sleep 1
      System.process
    }
    threads << Thread.new{
      controller_update_action :update_message => "this is a test message"
    }
    threads
  end

  def test2
    rand_edit
    edit_p_file
    System.process
  end

  def controller_update_action params
    @craft = @craft.reload
    @campaign = @campaign.reload
    commit = @craft.history.first
    if @campaign.reload.nothing_to_commit?
      @craft.commit_message = params[:update_message] #message may not be saved, but is set so that validations can be used to checks its ok to write to repo.
      if @craft.valid? #run validations
        @craft.change_commit_message(commit, params[:update_message]) #update the message to the repo
        if commit.eql?(@craft.history.first) #in the case where this is the current commit then 
          @craft.commit_message = nil #set the commit message to nil it has been written to the repo
        else
          @craft.reload #if not then reload the craft to restore the commit message to how it was before being used in the validation
        end         
      end
    else
      #if there are untracked changes in the repo the message is cached on the craft object, to be written to the repo later.
      @craft.commit_message = params[:update_message] if commit.to_s.eql?(@craft.history.first.to_s)
    end
    @craft.save if @craft.valid?
  end

  def process
    System.process
  end

  def commit
    @craft.commit
  end

end
#t = TestCraft.new(4, "athingybob", :vab)

