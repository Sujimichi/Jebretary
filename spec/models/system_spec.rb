require 'spec_helper'

describe System do
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

  describe "with created campaigns" do 
    before(:each) do 
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
      @campaign_1 = FactoryGirl.create(:campaign, :name => "test_campaign_1", :instance_id => @instance.id)
      @campaign_2 = FactoryGirl.create(:campaign, :name => "test_campaign_1", :instance_id => @instance.id)
    end

    it 'should comit the craft to the git repo' do 
      uncommitted_craft = (@campaign_1.new_and_changed[:new] - ["persistent.sfs", "quicksave.sfs"])
      uncommitted_craft.size.should == 3
      @campaign_1.craft.map{|c| c.history.empty?}.all?.should be_true
      @campaign_1.update_persistence_checksum
  
      System.process
      uncommitted_craft = (@campaign_1.new_and_changed[:new] - ["persistent.sfs", "quicksave.sfs"])
      uncommitted_craft.size.should == 0
      @campaign_1.craft.map{|c| c.history.empty?}.all?.should be_true
    end

    it 'should not attempt to commit craft which are already commited (and unchanged)' do 
      craft = @campaign_1.craft.new(:name =>  "test", :craft_type => "VAB")
      craft.should_not_receive(:commit)
      craft.stub!(:is_new? => false, :is_changed? => false, :history_count => 1)
      
      @campaign_1.stub!(:craft => [craft])
      a = [@campaign_1]
      a.stub!(:includes => [@campaign_1])
      @instance.stub!(:campaigns => a)

      Instance.stub!(:all => [@instance])
      System.process
    end

    it 'should commit craft which are changed' do 
      craft = @campaign_1.craft.create(:name =>  "test", :craft_type => "VAB")
      craft.should_receive(:commit).once
      craft.stub!(:is_new? => false, :is_changed? => true, :history_count => 1)
      
      @campaign_1.stub!(:craft => [craft])
      a = [@campaign_1]
      a.stub!(:includes => [@campaign_1])
      @instance.stub!(:campaigns => a)

      Instance.stub!(:all => [@instance])
      System.process
    end

    it 'should not process the craft if the campaign should_process returns false' do 
      craft = @campaign_1.craft.new(:name =>  "test", :craft_type => "VAB")
      craft.should_not_receive(:commit)
      craft.stub!(:is_new? => false, :is_changed? => true, :history_count => 1)
      
      @campaign_1.stub!(:craft => [craft])
      @campaign_1.stub!(:should_process? => false)
      a = [@campaign_1]
      a.stub!(:includes => [@campaign_1])
      @instance.stub!(:campaigns => a)
      Instance.stub!(:all => [@instance])
      System.process

    end
    
  end

end
