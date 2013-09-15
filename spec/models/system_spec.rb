require 'spec_helper'

describe System do

  describe "creating campaigns" do 
  before(:each) do 
    create_sample_data "test_campaign_1", :reset => true
    create_sample_data "test_campaign_2", :reset => false
    @instance = FactoryGirl.create(:instance)
    Dir.chdir File.join(@instance.path, "saves", "test_campaign_1")
    make_sample_data
    Dir.chdir File.join(@instance.path, "saves", "test_campaign_2")
    make_sample_data
  end


  it "should discover and create Campaign objects for each campaign" do 
    Campaign.all.should be_empty
    System.process

    Campaign.count.should == 2
    Campaign.all.map{|c| c.name}.should == ["test_campaign_1", "test_campaign_2"]
  end
  end

  describe "with created campaigns" do 
    before(:each) do 
      create_sample_data "test_campaign_1", :reset => true
      create_sample_data "test_campaign_2", :reset => false
      @instance = FactoryGirl.create(:instance)
      Dir.chdir File.join(@instance.path, "saves", "test_campaign_1")
      make_sample_data
      Dir.chdir File.join(@instance.path, "saves", "test_campaign_2")
      make_sample_data     
      @campaign_1 = FactoryGirl.create(:campaign, :name => "test_campaign_1", :instance_id => @instance.id)
      @campaign_2 = FactoryGirl.create(:campaign, :name => "test_campaign_1", :instance_id => @instance.id)
    end

    it 'should ensure a git repo has been created for each campaign' do 
      Dir.entries(@campaign_1.path).should_not be_include('.git')
      Dir.entries(@campaign_2.path).should_not be_include('.git')

      System.process
      Dir.entries(@campaign_1.path).should be_include('.git')
      Dir.entries(@campaign_2.path).should be_include('.git')
    end

    it 'should create craft objects for the campaigns' do 
      Craft.count.should == 0

      System.process
      @campaign_1.craft.should_not be_empty
      @campaign_2.craft.should_not be_empty
    end

  end
  
  describe "commiting the craft" do 
    before(:each) do 
      create_sample_data "test_campaign_1", :reset => true
      @instance = FactoryGirl.create(:instance)
      Dir.chdir File.join(@instance.path, "saves", "test_campaign_1")
      make_sample_data
      @campaign_1 = FactoryGirl.create(:campaign, :name => "test_campaign_1", :instance_id => @instance.id)
    end

    it 'should comit the craft to the git repo' do 
      uncommitted_craft = @campaign_1.new_and_changed[:new]
      uncommitted_craft.size.should == 3
      @campaign_1.craft.map{|c| c.history.empty?}.all?.should be_true
      @campaign_1.update_attributes(:persistence_checksum => nil)
  
      System.process
      uncommitted_craft = @campaign_1.reload.new_and_changed[:new]
      uncommitted_craft.size.should == 0
      @campaign_1.craft.map{|c| c.history.empty?}.all?.should be_false
    end

    it 'should not attempt to commit craft which are already commited (and unchanged)' do 
      craft = @campaign_1.craft.new(:name =>  "my_rocket", :craft_type => "vab")
      craft.should_not_receive(:commit)
      craft.stub!(:is_new? => false, :is_changed? => false, :history_count => 1, :deleted => false)

      a = [craft]
      a.stub!(:where => [craft])
      Craft.should_receive(:where).with(:campaign_id => @campaign_1.id, :deleted => false).at_least(1).times.and_return(a)     
      Craft.should_receive(:where).with(:campaign_id => @campaign_1.id).at_least(1).times.and_return(a)     
      System.process
    end

    it 'should commit craft which are changed' do 
      craft = @campaign_1.craft.create(:name =>  "my_rocket", :craft_type => "vab")
      craft.should_receive(:commit).once
      craft.stub!(:is_new? => false, :is_changed? => true, :history_count => 1)

      a = [craft]
      a.stub!(:where => [craft])
      Craft.should_receive(:where).with(:campaign_id => @campaign_1.id, :deleted => false).at_least(1).times.and_return(a)     
      Craft.should_receive(:where).with(:campaign_id => @campaign_1.id).at_least(1).times.and_return(a)     
      b = []
      b.stub!(:where => b)
      Craft.should_receive(:where).with("history_count is not null and campaign_id = #{@campaign_1.id}").at_least(1).times.and_return(b)

      System.process
    end

    it 'should not process the craft if the campaign should_process returns false' do 
      craft = @campaign_1.craft.new(:name =>  "my_rocket", :craft_type => "vab")
      craft.should_not_receive(:commit)
      craft.stub!(:is_new? => false, :is_changed? => true, :history_count => 1, :deleted => false)
      
      @campaign_1.stub!(:should_process? => false)
      Campaign.should_receive(:where).at_least(1).times.and_return([@campaign_1])
      a = [craft]
      a.stub!(:where => [craft])
      #Craft.should_receive(:where).with(:campaign_id => @campaign_1.id, :deleted => false).at_least(1).times.and_return(a)
      Craft.should_receive(:where).with(:campaign_id => @campaign_1.id).at_least(1).times.and_return(a)
      System.process
    end
    
  end

  describe "tracking deleted craft" do 
    before(:each) do 
      set_up_sample_data
      @campaign.create_repo
      System.process
    end

    it 'should create a new commit when a craft file is removed' do 
      @campaign.new_and_changed[:new].size.should == 0
      files = @instance.identify_craft_in @campaign.name
      files.map{|k,v| v}.flatten.size.should == 3
      File.delete("VAB/my_other_rocket.craft")

      files = @instance.identify_craft_in @campaign.name
      files.map{|k,v| v}.flatten.size.should == 2

      System.process
      @campaign.repo.log.first.message.should == "deleted my_other_rocket"
    end

  end


  describe "deleting a craft should not result in it appearing under all other campaigns" do 
    #This describes the behaviour of a bug found. Where deleting a craft would result in it being listed under all other campaigns.  
    #Somewhere at the point of marking the craft object as deleted it also gets created in all campaigns
    before(:each) do 
      @instance = FactoryGirl.create(:instance)
      create_sample_data "campaign_1"
      @campaign_1 = FactoryGirl.create(:campaign, :name => "campaign_1", :instance_id => @instance.id)
      Dir.chdir @campaign_1.path
      make_sample_data
      create_sample_data "campaign_2", :reset => false
      @campaign_2 = FactoryGirl.create(:campaign, :name => "campaign_2", :instance_id => @instance.id)
      Dir.chdir @campaign_2.path
      make_sample_data
      System.process
    end

    it 'should mark a craft as deleted in on campaign and not change the craft counts of another campaign.' do 
      Dir.chdir(@campaign_1.path)
      File.open("Ships/VAB/my_even_better_rocket.craft", "w"){|f| f.write("some_test_nonsense")}
      System.process

      @campaign_1.craft.count.should == 4
      @campaign_2.craft.count.should == 3

      Dir.chdir(@campaign_1.path)
      File.delete("Ships/VAB/my_even_better_rocket.craft")
      System.process

      @campaign_1.craft.count.should == 4
      @campaign_1.craft.where(:deleted => false).count.should == 3

      @campaign_2.craft.count.should == 3 #<<<===Bug causes this to not pass
      @campaign_2.craft.where(:deleted => false).count.should == 3

    end


  end
end
