require 'spec_helper'

describe Craft do

  describe "is_new?" do 
    before(:each) do 
      set_up_sample_data
      @campaign.create_repo      
      @craft = FactoryGirl.create(:craft, :campaign => @campaign, :name => "my_rocket", :craft_type => "vab")
    end

    it 'should return true if the craft is not in the repo' do 
      @craft.is_new?.should be_true
    end

    it 'should return false if the craft is in the repo' do 
      r = @campaign.repo
      r.add("Ships/VAB/my_rocket.craft")
      r.commit("added craft")
      @craft.is_new?.should be_false
    end

    it 'should return false if the craft is marked as deleted' do 
      @craft.update_attributes(:deleted => true)
      @craft.is_new?.should be_false
    end
  end

  describe "is_changed?" do 
    before(:each) do 
      set_up_sample_data
      @campaign.create_repo      
      @craft = FactoryGirl.create(:craft, :campaign => @campaign, :name => "my_rocket", :craft_type => "vab")
      @repo = @campaign.repo
    end    

    it 'should return nil if the craft is not in the repo' do 
      @craft.is_changed?.should be_nil
    end

    it 'should return true if the craft is in the repo and has changed' do 
      @repo.add("Ships/VAB/my_rocket.craft")
      @repo.commit("added craft")      
     
      File.open("Ships/VAB/my_rocket.craft", 'w'){|f| f.write("something different")}
      @craft.is_changed?.should be_true
    end

    it 'should return false if the craft is in the repo and is not changed' do 
      @repo.add("Ships/VAB/my_rocket.craft")
      @repo.commit("added craft")      

      @craft.is_changed?.should be_false
    end

    it 'should return false if the craft is marked as deleted' do 
      @repo.add("Ships/VAB/my_rocket.craft")
      @repo.commit("added craft")          
      File.open("Ships/VAB/my_rocket.craft", 'w'){|f| f.write("something different")}
      @craft.update_attributes(:deleted => true)

      @craft.is_changed?.should be_false
    end

  end

  
  describe "commit" do 
    before(:each) do 
      set_up_sample_data
      @campaign.create_repo
      @craft = FactoryGirl.create(:craft, :campaign => @campaign, :name => "my_rocket", :craft_type => "vab")
    end

    it "should add and commit a new craft file if it is not already in the repo and put 'added' in the commit message" do      
      @campaign.repo.untracked.should be_include "Ships/VAB/my_rocket.craft"

      @craft.commit      
      @campaign.repo.untracked.should_not be_include "Ships/VAB/my_rocket.craft"

      message = @campaign.repo.log("Ships/VAB/my_rocket.craft").first.message
      message.should contain "added"
      message.should contain "my_rocket"
    end

    it "should update and comit an existing craft that is already in the reop and put 'updated' in the commit mesage" do 
      repo = @campaign.repo
      repo.add("Ships/VAB/my_rocket.craft")
      repo.commit("added my_rocket")
      File.open("Ships/VAB/my_rocket.craft", 'w'){|f| f.write('something different')}
      
      @campaign.repo.untracked.should_not be_include "Ships/VAB/my_rocket.craft"

      @craft.commit
      message = @campaign.repo.log("Ships/VAB/my_rocket.craft").first.message
      message.should contain "updated"
      message.should contain "my_rocket"
    end 


    it 'should not commit anything if the craft has no changes' do 
      repo = @campaign.repo
      repo.add("Ships/VAB/my_rocket.craft")
      repo.commit("added my_rocket")

      @campaign.repo.untracked.should_not be_include "Ships/VAB/my_rocket.craft"

      @craft.commit
      @campaign.repo.log("Ships/VAB/my_rocket.craft").size.should == 1
    end

    it 'should set a given commit message if one is supplied' do 
      repo = @campaign.repo
      @craft.commit :m => "custom message"
      message = @campaign.repo.log("Ships/VAB/my_rocket.craft").first.message
      message.should == "custom message"
    end

    it 'should commit a deleted craft' do 
      repo = @campaign.repo
      @craft.commit
      File.delete("Ships/VAB/my_rocket.craft")
      @craft.deleted = true

      action = @craft.commit

      action.should == :deleted
      @campaign.repo.log.first.message.should == "deleted #{@craft.name}"
    end

    it 'should set the last_commit attr with the sha_id of its latest commit' do 
      @craft.last_commit.should be_nil
      repo = @campaign.repo
      @craft.commit
      first_commit_sha = repo.log.first
      first_commit_sha.message.should == "added my_rocket"

      @craft.last_commit.should == first_commit_sha.to_s
      
      File.delete("Ships/VAB/my_rocket.craft")
      @craft.deleted = true
      @craft.commit
      latest_commit_sha = repo.log.first
      latest_commit_sha.message.should == "deleted my_rocket"

      @craft.last_commit.should == latest_commit_sha.to_s
    end


  end

  describe "history" do    
    before(:each) do 
      set_up_sample_data
      File.open("Ships/VAB/my_rocket.craft", "w"){|f| f.write("first version")}
      @campaign.create_repo
      @craft = FactoryGirl.create(:craft, :campaign => @campaign, :name => "my_rocket", :craft_type => "vab")
      @craft.should be_new_craft
    end

    it 'should return the commits for a craft (newest first)' do 
      @craft.commit
      @craft.history.size.should == 1
      @craft.history.first.should be_a Repo::Commit

      sleep(2) #to ensure a difference in commit date stamps
      File.open("Ships/VAB/my_rocket.craft", "w"){|f| f.write("second version")}
      @craft.commit
      @craft.history.size.should == 2
      (@craft.history[0].date > (@craft.history[1].date)).should be_true

      @craft.history.map{|log| log.message}.should == ["updated my_rocket", "added my_rocket"]


      #raise @craft.history.first.methods.sort - Class.new.methods
      #[:archive, :author, :author_date, :blob?, :commit?, :committer, :committer_date, :contents, :contents_array, :date, :diff, :diff_parent, :grep, :gtree, :log, :message, :mode, :mode=, :objectish, :objectish=, :set_commit, :sha, :size, :size=, :tag?, :tree?, :type, :type=]


    end

    it 'should return an empty array if the craft is marked as deleted' do 
      @craft.commit
      File.delete("Ships/VAB/my_rocket.craft")
      @craft.update_attributes(:deleted => true)
      @craft.history.should == []
    end
  end


  describe "revert_to" do 
    before(:each) do 
      set_up_sample_data
      File.open("Ships/VAB/my_rocket.craft", "w"){|f| f.write("first version")}
      @campaign.create_repo
      @craft = FactoryGirl.create(:craft, :campaign => @campaign, :name => "my_rocket", :craft_type => "vab")
      @craft.commit
      File.open("Ships/VAB/my_rocket.craft", "w"){|f| f.write("second version")}
      @craft.commit
      File.open("Ships/VAB/my_rocket.craft", "w"){|f| f.write("third version")}
      @craft.commit
    end

    it 'should revert a craft to a previous version' do 
      commit = @craft.history[2]
      @craft.revert_to commit
      File.open("Ships/VAB/my_rocket.craft", "r"){|f| f.readlines}.join.should == "first version"
      @craft.history.first.message.should contain "reverted my_rocket"
            
      commit = @craft.history[2] #same index as there is now another commit 
      @craft.revert_to commit
      File.open("Ships/VAB/my_rocket.craft", "r"){|f| f.readlines}.join.should == "second version"
      @craft.history.first.message.should contain "reverted my_rocket"

      commit = @craft.history.select{|log| log.message == "updated my_rocket"}.first
      @craft.revert_to commit
      File.open("Ships/VAB/my_rocket.craft", "r"){|f| f.readlines}.join.should == "third version"
      @craft.history.first.message.should contain "reverted my_rocket"

    end

    it 'should put the version number it reverted to in the commit message' do 
      commit = @craft.history[2]
      @craft.revert_to commit
      File.open("Ships/VAB/my_rocket.craft", "r"){|f| f.readlines}.join.should == "first version"
      @craft.history.first.message.should == "reverted my_rocket to V1"

      commit = @craft.history[2]
      @craft.revert_to commit
      File.open("Ships/VAB/my_rocket.craft", "r"){|f| f.readlines}.join.should == "second version"
      @craft.history.first.message.should == "reverted my_rocket to V2"
    end

    describe "without commiting" do 

      it 'should revert the contents of the file but not commit the change' do 
        hist_count = @craft.history.size
        commit = @craft.history[2]       
        @craft.revert_to commit, :commit => false
        File.open("Ships/VAB/my_rocket.craft", "r"){|f| f.readlines}.join.should == "first version"
        @craft.history.size.should == hist_count
      end

    end
  end

  describe "recover deleted craft" do 
    before(:each) do 
      set_up_sample_data
      File.open("Ships/VAB/my_rocket.craft", "w"){|f| f.write("first version")}
      @campaign.create_repo
      @craft = FactoryGirl.create(:craft, :campaign => @campaign, :name => "my_rocket", :craft_type => "vab")
      @craft.commit
      File.delete("Ships/VAB/my_rocket.craft")
      @craft.deleted = true
      @craft.commit
    end

    it 'should recover the deleted craft file' do 
      @craft.recover
      File.exists?("Ships/VAB/my_rocket.craft").should be_true
      File.open("Ships/VAB/my_rocket.craft", "r"){|f| f.readlines}.join.should == "first version"
    end

    it 'should set the crafts deleted attribute to false' do 
      @craft.should be_deleted
      @craft.recover
      @craft.should_not be_deleted
    end

    it 'should commit the recovery with a message recovered <craft_name>' do 
      @craft.recover
      @craft.history.size.should == 3
      @craft.history.first.message.should == "recovered my_rocket"
    end

    it 'should updated the crafts history_count and last_commit attributes' do 
      @craft.recover
      @craft.history_count.should == 3
      @craft.last_commit.should == @campaign.repo.log.first.to_s
    end


  end


  describe "change_commit_message" do 
    before(:each) do 
      set_up_sample_data
      File.open("Ships/VAB/my_rocket.craft", "w"){|f| f.write("first version")}
      @campaign.create_repo
      @campaign.track_save(:both)
      @craft = FactoryGirl.create(:craft, :campaign => @campaign, :name => "my_rocket", :craft_type => "vab")
      @craft.commit :m => "first commit"
      File.open("Ships/VAB/my_rocket.craft", "w"){|f| f.write("second version")}
      @craft.commit :m => "second commit"
      File.open("Ships/VAB/my_rocket.craft", "w"){|f| f.write("third version")}
      @craft.commit :m => "third commit"  
      System.process #to commit the other craft
    end


    it 'should be able to change the most recent commit message' do 
      most_recent_commit = @craft.history.first
      most_recent_commit.message.should == "third commit"
      @craft.change_commit_message most_recent_commit, "this is the third commit"

      @craft.reload.history.first.message.should == "this is the third commit"
    end

    it 'should be able to change a specific commit message' do 
      commit = @craft.history[1]
      commit.message.should == "second commit"
      @craft.change_commit_message commit, "this is a new message"

      @craft.reload.history[1].message.should == "this is a new message"
    end

    it 'should not result in additional commits' do 
      @craft.history.size.should == 3
      commit = @craft.history[1]
      commit.message.should == "second commit"
      @craft.change_commit_message commit, "this is a new message"

      @craft.reload.history.size.should == 3
    end

    it 'should not try to change the commit message if the repo has untracked changes' do 
      commit = @craft.history[1]
      @craft.change_commit_message(commit, "this is a new message").should be_true
      @other_craft = Craft.where(:campaign_id => @craft.id, :name => "my_other_rocket").first
      change_craft_contents @other_craft, "this is some different file data"

      @craft.change_commit_message(commit, "this is a new test message").should be_false
    end

  end

  describe "deleting craft" do 
    before(:each) do 
      set_up_sample_data
      File.open("Ships/VAB/my_rocket.craft", "w"){|f| f.write("first version")}
      @campaign.create_repo
      @craft = FactoryGirl.create(:craft, :campaign => @campaign, :name => "my_rocket", :craft_type => "vab")
      @craft.commit
    end

    it 'should delete the craft file from the campaign' do 
      File.should be_exists("Ships/VAB/my_rocket.craft")          
      @craft.delete_craft
      File.should_not be_exists("Ships/VAB/my_rocket.craft")      
      @craft.should be_deleted
    end

    it 'should not call delete on an already deleted craft' do 
      File.should_receive(:delete).with(File.join([@craft.campaign.path, @craft.file_name])).once
      @craft.delete_craft
      File.should_not_receive(:delete).with(File.join([@craft.campaign.path, @craft.file_name]))
      @craft.delete_craft
    end

  end

  describe "move_to" do 
    before(:each) do 
      make_campaign_dir "test_campaign_1", :reset => true
      make_campaign_dir "test_campaign_2", :reset => false
      @instance = FactoryGirl.create(:instance)
      Dir.chdir File.join(@instance.path, "saves", "test_campaign_1")
      make_sample_data
      Dir.chdir File.join(@instance.path, "saves", "test_campaign_2")
      make_sample_data
      System.process

      @campaign_1 = Campaign.where(:name => "test_campaign_1").first
      @campaign_2 = Campaign.where(:name => "test_campaign_2").first
      make_new_craft_in @campaign_1, "VAB", "some_brand_new_rocket"
      @craft = @campaign_1.craft.create!(:name => "some_brand_new_rocket", :craft_type => :vab)
      @craft.commit
    end

    it 'should move the craft file from one campaign to another' do 
      @craft.campaign.should == @campaign_1      
      @campaign_1.craft.map{|c| c.name}.should be_include(@craft.name)
      @campaign_2.craft.map{|c| c.name}.should_not be_include(@craft.name)
      Dir.entries(File.join([@campaign_1.path, "Ships", "VAB"])).should be_include("#{@craft.name}.craft")
      Dir.entries(File.join([@campaign_2.path, "Ships", "VAB"])).should_not be_include("#{@craft.name}.craft")

      @craft.move_to @campaign_2

      Dir.entries(File.join([@campaign_1.path, "Ships", "VAB"])).should_not be_include("#{@craft.name}.craft")
      Dir.entries(File.join([@campaign_2.path, "Ships", "VAB"])).should be_include("#{@craft.name}.craft")
      @campaign_1.reload.craft.map{|c| c.name}.should_not be_include(@craft.name)
      @campaign_2.reload.craft.map{|c| c.name}.should be_include(@craft.name)
      @craft.campaign.should == @campaign_2     
    end

    it 'should not move the craft if one is already present' do 
      File.open(@craft.file_path,'w'){|f| f.write("something particular written in this craft")}
      make_new_craft_in @campaign_2, "VAB", "some_brand_new_rocket"
      @craft2 = @campaign_2.craft.create!(:name => "some_brand_new_rocket", :craft_type => :vab)
      @craft2.commit

      @craft.move_to(@campaign_2).should be_false
      File.open(@craft2.file_path,'r'){|f| f.readline}.should == "some test data"
      @craft.campaign.should == @campaign_1
    end

    it 'should move the craft if one is already present if it is given the replace option' do 
      File.open(@craft.file_path,'w'){|f| f.write("something particular written in this craft")}
      make_new_craft_in @campaign_2, "VAB", "some_brand_new_rocket"
      @craft2 = @campaign_2.craft.create!(:name => "some_brand_new_rocket", :craft_type => :vab)
      @craft2.commit

      @craft.move_to(@campaign_2, :replace => true).should be_true
      File.open(@craft2.file_path,'r'){|f| f.readline}.should == "something particular written in this craft"
      Craft.where(:name => "some_brand_new_rocket").count.should == 2
      Craft.where(:name => "some_brand_new_rocket").first.campaign.should == @campaign_1
      Craft.where(:name => "some_brand_new_rocket").first.should be_deleted
      Craft.where(:name => "some_brand_new_rocket").last.campaign.should == @campaign_2

    end

    it 'should leave the originals in place if given the copy option' do 
      @craft.campaign.should == @campaign_1      
      @campaign_1.craft.map{|c| c.name}.should be_include(@craft.name)
      @campaign_2.craft.map{|c| c.name}.should_not be_include(@craft.name)
      Dir.entries(File.join([@campaign_1.path, "Ships", "VAB"])).should be_include("#{@craft.name}.craft")
      Dir.entries(File.join([@campaign_2.path, "Ships", "VAB"])).should_not be_include("#{@craft.name}.craft")

      @craft.move_to @campaign_2, :copy => true

      Dir.entries(File.join([@campaign_1.path, "Ships", "VAB"])).should be_include("#{@craft.name}.craft")
      Dir.entries(File.join([@campaign_2.path, "Ships", "VAB"])).should be_include("#{@craft.name}.craft")
      @campaign_1.reload.craft.map{|c| c.name}.should be_include(@craft.name)
      @campaign_2.reload.craft.map{|c| c.name}.should be_include(@craft.name)
      @craft.campaign.should == @campaign_1
      Craft.where(:name => "some_brand_new_rocket").count.should == 2      
    end

  end


  describe "campaign spanning" do 
    before(:each) do 
      make_campaign_dir "test_campaign_1", :reset => true
      make_campaign_dir "test_campaign_2", :reset => false
      @instance = FactoryGirl.create(:instance)
      Dir.chdir File.join(@instance.path, "saves", "test_campaign_1")
      make_sample_data
      Dir.chdir File.join(@instance.path, "saves", "test_campaign_2")
      make_sample_data
      System.process

      @campaign_1 = Campaign.where(:name => "test_campaign_1").first
      @campaign_2 = Campaign.where(:name => "test_campaign_2").first
      make_new_craft_in @campaign_1, "VAB", "some_brand_new_rocket"
      @craft = @campaign_1.craft.create!(:name => "some_brand_new_rocket", :craft_type => :vab)
      @craft.commit
    end

    it 'should enable a craft to exist in multiple campaigns and relect changes made in one campaign over all selected campaigns'

  end

end
