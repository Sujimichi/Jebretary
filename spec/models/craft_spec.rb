require 'spec_helper'

describe Craft do
  
  describe "identify_craft" do 
    before(:each) do 
      @campaign = set_up_sample_data
    end

    it 'should identify all present craft files in VAB and SPH' do 
      files = Craft.identify_craft_in(@campaign)
      files.should be_a(Hash)
      files.should have_key(:vab)
      files.should have_key(:sph)
      files[:vab].should be_a(Array)
      files[:sph].should be_a(Array)
      
      files[:vab].should contain("my_rocket.craft")
      files[:vab].should contain("my_other_rocket.craft")
      files[:sph].should contain("my_rocket_car.craft")
    end

    it 'should not track non .craft files' do 
      Dir.chdir("Ships/VAB")
      File.open("not_a_craft.file", "w"){|f| f.write("some test data")}
      files = Craft.identify_craft_in(@campaign)
      files[:vab].should_not contain("not_a_craft.file")
    end


  end


  describe "verify_craft_for campaign" do 
    before(:each) do 
      @campaign = set_up_sample_data
    end

    it 'should create a Craft model for each craft identified' do 
      Craft.count.should == 0
      @campaign.craft.should be_empty
      Craft.verify_craft_for @campaign
      Craft.count.should == 3
      @campaign.reload
      @campaign.craft.size.should == 3
      @campaign.craft.select{|craft| craft.craft_type == "vab"}.size.should == 2
      @campaign.craft.select{|craft| craft.craft_type == "sph"}.size.should == 1
      @campaign.craft.map{|craft| craft.name}.sort.should == ['my_rocket', 'my_other_rocket', 'my_rocket_car'].sort
    end

    it 'should not create a new craft object if one for that name and type already exists' do 
      Craft.verify_craft_for @campaign
      @campaign.craft.size.should == 3
      Dir.chdir("SPH")
      File.open("my_other_rocket.craft",'w'){|f| f.write("slkjlksjfj")} #create a craft in SPH with same name as one in VAB
      Craft.verify_craft_for @campaign
      @campaign.craft.size.should == 4
    end

    it 'should mark existing craft objects as deleted if the .craft file is no longer present' do 
      Craft.verify_craft_for @campaign
      @campaign.craft.map{|craft| craft.deleted?}.all?.should be_false
      File.delete("VAB/my_other_rocket.craft")
      Craft.verify_craft_for @campaign
      @campaign.craft.map{|craft| craft.deleted? }.all?.should be_false
      @campaign.craft.where(:craft_type => 'vab', :name => "my_other_rocket").first.deleted.should be_true
    end
  end
  

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
      @craft.history.first.message.should == "reverted my_rocket"
            
      commit = @craft.history[2] #same index as there is now another commit 
      @craft.revert_to commit
      File.open("Ships/VAB/my_rocket.craft", "r"){|f| f.readlines}.join.should == "second version"
      @craft.history.first.message.should == "reverted my_rocket"

      commit = @craft.history.select{|log| log.message == "updated my_rocket"}.first
      @craft.revert_to commit
      File.open("Ships/VAB/my_rocket.craft", "r"){|f| f.readlines}.join.should == "third version"
      @craft.history.first.message.should == "reverted my_rocket"

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

end
