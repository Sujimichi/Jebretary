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
      @campaign.repo.status["Ships/VAB/my_rocket.craft"].untracked.should be_true

      @craft.commit      
      @campaign.repo.status["Ships/VAB/my_rocket.craft"].untracked.should be_false
      message = @campaign.repo.log.object("Ships/VAB/my_rocket.craft").to_a.first.message
      message.should contain "added"
      message.should contain "my_rocket"
    end

    it "should update and comit an existing craft that is already in the reop and put 'updated' in the commit mesage" do 
      repo = @campaign.repo
      repo.add("Ships/VAB/my_rocket.craft")
      repo.commit("added my_rocket")
      File.open("Ships/VAB/my_rocket.craft", 'w'){|f| f.write('something different')}
      @campaign.repo.status["Ships/VAB/my_rocket.craft"].untracked.should be_false
      @campaign.repo.status["Ships/VAB/my_rocket.craft"].type.should == "M"

      @craft.commit
      message = @campaign.repo.log.object("Ships/VAB/my_rocket.craft").to_a.first.message
      message.should contain "updated"
      message.should contain "my_rocket"
    end 


    it 'should not commit anything if the craft has no changes' do 
      repo = @campaign.repo
      repo.add("Ships/VAB/my_rocket.craft")
      repo.commit("added my_rocket")
      @campaign.repo.status["Ships/VAB/my_rocket.craft"].untracked.should be_false
      @campaign.repo.status["Ships/VAB/my_rocket.craft"].type.should be_nil

      @craft.commit
      @campaign.repo.log.object("Ships/VAB/my_rocket.craft").to_a.size.should == 1
    end

    it 'should set a given commit message if one is supplied' do 
      repo = @campaign.repo
      @craft.commit :m => "custom message"
      message = @campaign.repo.log.object("Ships/VAB/my_rocket.craft").to_a.first.message
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
      @craft.history.first.should be_a Git::Object::Commit

      sleep(2) #to ensure a difference in commit date stamps
      File.open("Ships/VAB/my_rocket.craft", "w"){|f| f.write("second version")}
      @craft.commit
      @craft.history.size.should == 2
      (@craft.history[0].date > (@craft.history[1].date)).should be_true

      @craft.history.map{|log| log.message}.should == ["updated my_rocket", "added my_rocket"]

=begin
      raise @craft.history.first.methods.sort - Class.new.methods
      [:archive, :author, :author_date, :blob?, :commit?, :committer, :committer_date, :contents, :contents_array, :date, :diff, :diff_parent, :grep, :gtree, :log, :message, :mode, :mode=, :objectish, :objectish=, :set_commit, :sha, :size, :size=, :tag?, :tree?, :type, :type=]
=end

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
      @craft = FactoryGirl.create(:craft, :campaign => @campaign, :name => "my_rocket", :craft_type => "vab")
      @craft.commit :m => "first commit"
      File.open("Ships/VAB/my_rocket.craft", "w"){|f| f.write("second version")}
      @craft.commit :m => "second commit"
      File.open("Ships/VAB/my_rocket.craft", "w"){|f| f.write("third version")}
      @craft.commit :m => "third commit"  
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

  end

  describe "dont_process_campaign_while" do 
    before(:each) do 
      set_up_sample_data
      File.open("Ships/VAB/my_rocket.craft", "w"){|f| f.write("first version")}
      @campaign.create_repo
      @craft = FactoryGirl.create(:craft, :campaign => @campaign, :name => "my_rocket", :craft_type => "vab")
      @craft.commit
    end

    it "should set the campaigns persistent_checksum to 'skip' while the block is being called" do 
      @craft.campaign.update_persistence_checksum
      @craft.campaign.persistence_checksum.should_not be_nil
      @craft.dont_process_campaign_while do 
        @craft.campaign.persistence_checksum.should == "skip"
      end
      @craft.campaign.persistence_checksum.should_not == "skip"

    end


  end

end
