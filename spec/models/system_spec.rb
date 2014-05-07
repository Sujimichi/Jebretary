require 'spec_helper'

describe System do

  describe "creating campaigns" do 
    before(:each) do 
      make_campaign_dir "test_campaign_1", :reset => true
      make_campaign_dir "test_campaign_2", :reset => false
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
      make_campaign_dir "test_campaign_1", :reset => true
      make_campaign_dir "test_campaign_2", :reset => false
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
      make_campaign_dir "test_campaign_1", :reset => true
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
      craft.commit #commit to set the craft as being unchanged. new System design means stubbing is_new? and is_changed does not effect which craft are processed.
      craft.reload
      craft.should_not_receive(:commit)
      #craft.stub!(:is_new? => false, :is_changed? => false, :history_count => 1, :deleted => false)

      a = [craft]
      a.stub!(:where => [craft])
      #a.should_receive(:where).with(:history_count => nil).and_return([])
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

  describe "writing commit messages during a update or revert" do 
    before(:each) do 
      set_up_sample_data
      @campaign.create_repo
      System.process
      @campaign.track_save :both
      @craft = @campaign.craft.first
      change_craft_contents @craft, "version 2"
      @craft.commit
      @craft.history.size.should == 2
      
    end

    it 'should write the standard message during the commit when the craft has been changed' do 
      change_craft_contents @craft, "version 3"
      @craft.is_changed?.should be_true    

      File.open(File.join([@craft.campaign.path, "persistent.sfs"]), "w"){|f| f.write "pfile update"}
      @craft.campaign.update_attributes(:persistence_checksum => nil)
      System.process

      @craft.is_changed?.should be_false
      @craft.history.size.should ==3       
      @craft.commit_messages.keys.should be_empty 
      @craft.history.first.message.should == "updated #{@craft.name}"
    end

    it 'should write the custom message during the commit when the craft has been changed' do 
      change_craft_contents @craft, "version 3"
      @craft.is_changed?.should be_true    

      @craft.commit_messages = {"most_recent" => "this message was updated"}
      @craft.save

      File.open(File.join([@craft.campaign.path, "persistent.sfs"]), "w"){|f| f.write "pfile update"}
      @craft.campaign.update_attributes(:persistence_checksum => nil)
      System.process

      @craft.reload
      @craft.is_changed?.should be_false
      @craft.history.size.should ==3       
      @craft.history.first.message.should == "this message was updated"     
      @craft.commit_messages.keys.should be_empty 
    end  

    it 'should write the message during the commit when the craft has been reverted' do 
      first_commit = @craft.history.last #because history is given newest first
      @craft.revert_to first_commit, :commit => false
      @craft.is_changed?.should be_true
      @craft.commit_messages.keys.should be_include "most_recent"
      @craft.commit_messages["most_recent"].should == "reverted #{@craft.name} to V1"

      File.open(File.join([@craft.campaign.path, "persistent.sfs"]), "w"){|f| f.write "pfile update"}
      @craft.campaign.update_attributes(:persistence_checksum => nil)
      System.process 

      @craft.reload
      @craft.is_changed?.should be_false
      @craft.history.size.should ==3       
      @craft.history.first.message.should == "reverted #{@craft.name} to V1"
      @craft.commit_messages.keys.should be_empty 
    end

  end

  describe "tracking deleted craft" do 
    before(:each) do 
      set_up_sample_data
      @campaign.create_repo
      System.process
    end

    it 'should create a new commit when a craft file is removed' do 
      System.process
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
      make_campaign_dir "campaign_1"
      @campaign_1 = FactoryGirl.create(:campaign, :name => "campaign_1", :instance_id => @instance.id)
      Dir.chdir @campaign_1.path
      make_sample_data
      make_campaign_dir "campaign_2", :reset => false
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

  describe "tracking saves" do 
    before(:each) do 
      @campaign = set_up_sample_data
      @campaign.create_repo
      @campaign.verify_craft
      @campaign.craft.each{|c| c.commit}
      @campaign.repo.untracked.should be_include("quicksave.sfs")
      @campaign.repo.untracked.should be_include("persistent.sfs")
    end

    it 'should add the quicksave.sfs and persistent.sfs files to the repo' do 
      System.process
      @campaign.repo.untracked.should_not be_include("quicksave.sfs")
      @campaign.repo.untracked.should_not be_include("persistent.sfs")
    end

    it 'should not track the save files when there are craft being tracked' do 
      @campaign.track_save(:both) #to get saves files tracked
      change_craft_contents @campaign.craft.first, "some different file data"
      File.open(File.join([@campaign.path, 'quicksave.sfs']),'w'){|f| f.write("test data type stuff")}
      File.open(File.join([@campaign.path, 'persistent.sfs']),'w'){|f| f.write("test data type stuff")}
      System.process
      @campaign.repo.untracked.should be_empty
      @campaign.repo.changed.sort.should == [ 'persistent.sfs', 'quicksave.sfs'].sort

    end

    it 'should track the save files when craft are not being updated' do 
      @campaign.track_save(:both) #to get saves files tracked

      File.open(File.join([@campaign.path, 'quicksave.sfs']),'w'){|f| f.write("test data type stuff")}
      File.open(File.join([@campaign.path, 'persistent.sfs']),'w'){|f| f.write("test data type stuff")}
      System.process
      @campaign.repo.untracked.should be_empty
      @campaign.repo.changed.should == []
    end
  end

  describe "tracking subassemblies" do 
    before :each do 
      @campaign = set_up_sample_data
      make_sample_subassemblies 
      @campaign.create_repo     
    end

    it 'should add subassemblies that are found to the db' do 
      Subassembly.count.should == 0
      System.process 
      Subassembly.count.should == 2
    end

    it 'should track new subassemblies' do 
      @campaign.repo.tracked.should_not be_include "Subassemblies/subass1.craft"
      @campaign.repo.tracked.should_not be_include "Subassemblies/subass2.craft"
      System.process 

      @campaign.repo.tracked.should be_include "Subassemblies/subass1.craft"
      @campaign.repo.tracked.should be_include "Subassemblies/subass2.craft"
    end

    it 'should update existing subassemblies' do 
      @campaign.verify_subassemblies
      @campaign.repo.tracked.should be_include "Subassemblies/subass1.craft"
      @campaign.repo.tracked.should be_include "Subassemblies/subass2.craft"

      @sub = Subassembly.where(:name => "subass1").first
      @sub.history.first.message.should == "added subassembly: subass1"

      path = File.join([@campaign.path,"Subassemblies", "subass1.craft"])
      File.open(path, "w"){|f| f.write("some different test data")}
      
      System.process
      @sub.history.first.message.should == "updated subassembly: subass1"

    end


  end

  describe "commit messages" do 
    before(:each) do 
      @campaign = set_up_sample_data
      @campaign.create_repo
      @campaign.verify_craft
      @campaign.craft.each{|c| c.commit}
      System.process
      @craft = @campaign.craft.first
    end

    it 'should write messages which are on craft objects to the repo' do 
      commit = @craft.history.first
      commit.message.should == "added #{@craft.name}"
      @craft.commit_messages = {commit.to_s=> "this is a message apparently"}
      @craft.save

      System.process
      @craft.reload
      @craft.history.first.message.should == "this is a message apparently"
    end

    it 'should update multiple commit messages held on a single carft' do 
      sleep(0.5)
      change_craft_contents @craft, "foobar"
      @craft.commit
      @craft.history.size.should == 2
      @craft.history.map{|h| h.message}.should == ["updated #{@craft.name}", "added #{@craft.name}"]

      msgs = {}
      msgs[@craft.history[0]] = "change to update message"
      msgs[@craft.history[1]] = "change to add message"
      @craft.commit_messages = msgs
      @craft.save

      System.process
      @craft.reload
      @craft.history.map{|h| h.message}.should == ["change to update message", "change to add message"]
    end


    it 'should update messages from multiple craft' do 
      @craft2 = @campaign.craft.last
      
      @craft.commit_messages = {@craft.history.first   => "this is a message on craft 1"}
      @craft2.commit_messages = {@craft2.history.first => "this is a message on craft 2"}
      [@craft, @craft2].each{|c| c.save}

      System.process
      [@craft, @craft2].each{|c| c.reload}

      @craft.history.first.message.should == "this is a message on craft 1"
      @craft.commit_messages.should == {}
      @craft2.history.first.message.should == "this is a message on craft 2"
      @craft2.commit_messages.should == {}

    end

    it 'should not update commit messages if there is a change on the craft' do 
      @craft.commit_messages = {@craft.history.first.to_s=> "this is a message apparently"}
      @craft.save
      change_craft_contents @craft, "foobar"

      System.process
      @craft.reload
      @craft.history.first.message.should == "added #{@craft.name}"
    end

    it 'should not update commit message if there is a change on another craft' do 
      @craft.commit_messages = {@craft.history.first.to_s=> "this is a message apparently"}
      @craft.save
      change_craft_contents @campaign.craft.last, "foobar"

      System.process
      @craft.reload
      @craft.history.first.message.should == "added #{@craft.name}"
    end

    it 'should not matter which order craft have been updated in' do 
      @craft2 = @campaign.craft.last

      [@craft, @craft2].sort_by{rand}.each{|craft|
        change_craft_contents craft, "foobar"
        craft.commit
        sleep(1)
      }    
            
      @craft.commit_messages = {@craft.history.first   => "this is a message on craft 1"}
      @craft2.commit_messages = {@craft2.history.first => "this is a message on craft 2"}
      [@craft, @craft2].each{|c| c.save}
      
      System.process
      [@craft, @craft2].each{|c| c.reload}

      @craft.history.first.message.should == "this is a message on craft 1"
      @craft2.history.first.message.should == "this is a message on craft 2"
    end

    it 'should set the most_recent message update on the most recent commit' do 
      @craft.history.count.should == 1
      change_craft_contents @craft, "foobar"
      @craft.commit_messages = {"most_recent" => "this is a message apparently"}
      @craft.save

      @campaign.stub(:should_process? => true)
      Campaign.stub(:where => [@campaign])
      System.process

      @craft.reload
      @craft.history.count.should == 2
      @craft.history.first.message.should == "this is a message apparently"
    end

  end

  describe "general usage" do 
    before(:each) do 
      @campaign = set_up_sample_data
      @campaign.create_repo
      @campaign.verify_craft
      @campaign.craft.each{|c| c.commit}
      System.process
      @craft1 = @campaign.craft[0]
      @craft2 = @campaign.craft[1]
    end

    it 'should do things' do 
      @craft1.history.size.should == 1 #initial state of play

      #make a change to 1 craft and set a commit message
      change_craft_contents @craft1, "first version"
      @craft1.commit_messages = {"most_recent" => "first version"}
      @craft1.save

      #edit P file to simulate craft being launched
      File.open("persistent.sfs", 'w') {|f| f.write("some different test data") }

      System.process
      @craft1.reload

      @craft1.history.size.should == 2
      @craft1.history.first.message.should == "first version"    
      @craft1.commit_messages.keys.size.should == 0


      #2nd set of changes and launch
      change_craft_contents @craft1, "second version"
      msgs = @craft1.commit_messages
      msgs["most_recent"] = "second version"
      @craft1.commit_messages = msgs
      @craft1.save

      #edit P file to simulate craft being launched
      File.open("persistent.sfs", 'w') {|f| f.write("some more different test data") }

      System.process
      @craft1.reload

      @craft1.history.size.should == 3
      @craft1.history.first.message.should == "second version"
      @craft1.commit_messages.keys.size.should == 0 #should now be two commit messages not yet written to repo

      #edit P file to simulate craft autosave
      File.open("persistent.sfs", 'w') {|f| f.write("autowash") }
      System.process
      @craft1.reload

      @craft1.commit_messages.should be_empty #messages should now be written to repo and no longer stored on craft
      @craft1.history.map{|h| h.message}.should == ["second version", "first version", "added #{@craft1.name}"]
    end
  end
end
