require 'spec_helper'


describe Campaign do

  describe "creating a git repo" do 
    before(:each) do 
      set_up_sample_data
    end

    it 'should create a new repo if none exists' do 
      Dir.entries(@campaign.path).sort.should == ["persistent.sfs", "Ships", "quicksave.sfs", ".", ".."].sort
      @campaign.create_repo
      Dir.entries(@campaign.path).should contain('.git')
    end

    it 'should add a .gitignore to the repo' do 
      @campaign.create_repo
      g = Repo.open(@campaign.path)
      Dir.entries(@campaign.path).should contain('.git')
      g.log(".gitignore").first.should be_a Repo::Commit
      g.log(".gitignore").first.message.should_not contain("unknown revision or path")
    end


    it 'should not attempt to create if repo already exists' do 
      @campaign.create_repo
      g = Repo.open(@campaign.path)
      Repo.should_not_receive(:init)
      @campaign.create_repo
    end

  end

  describe "new_and_changed_keys" do 
    before(:each) do 
      set_up_sample_data
      verify_craft_for_campaign
      commit_craft_in_campaign
      make_new_craft_in @campaign, "VAB", "rocket_thing"
    end

    it 'should return a hash containing :new and :changed keys' do 
      @campaign.new_and_changed.keys.sort.should == [:changed, :new]
    end

    it 'should reference new craft in :new' do 
      @campaign.new_and_changed[:new].should be_include "Ships/VAB/rocket_thing.craft"
    end

    it 'should reference changed craft in :changed' do 
      File.open("my_rocket.craft", 'w') {|f| f.write("some changed test data") }
      @campaign.new_and_changed[:changed].should be_include "Ships/VAB/my_rocket.craft"
    end

    it 'should not include persistence and quicksave files' do 
      @campaign.new_and_changed[:new].should_not be_include "persistent.sfs"
      @campaign.new_and_changed[:new].should_not be_include "quicksave.sfs"
      @campaign.new_and_changed[:new].should_not be_include "kethane.cfg"
    end

  end

  describe "has_untracked_changes?" do 
    before(:each) do 
      set_up_sample_data
      verify_craft_for_campaign
      commit_craft_in_campaign      
      @campaign.track_save(:quicksave)
      @campaign.track_save(:persistent)
      Dir.chdir(@campaign.path)
    end

    it 'should return true if there are changed craft' do 
      File.open(File.join([@campaign.path, @campaign.craft.first.file_name]),'w'){|f| f.write("foobar")}
      @campaign.should have_untracked_changes
      @campaign.new_and_changed[:new].should be_empty
      @campaign.new_and_changed[:changed].should_not be_empty
    end

    it 'should return false if all craft are up-to-date' do 
      File.open(File.join([@campaign.path, @campaign.craft.first.file_name]),'w'){|f| f.write("foobar")}     
      @campaign.should have_untracked_changes
      @campaign.craft.first.commit
      @campaign.should_not have_untracked_changes
    end

    it 'should return true if the quicksave.sfs is changed' do 
      @campaign.should_not have_untracked_changes
      File.open('quicksave.sfs','w'){|f| f.write("foobar")}           
      @campaign.should have_untracked_changes
    end

    it 'should return true if the persistent.sfs is changed' do 
      @campaign.should_not have_untracked_changes
      File.open('persistent.sfs','w'){|f| f.write("foobar")}           
      @campaign.should have_untracked_changes
    end

    it 'should return true if a craft has been deleted' do      
      @campaign.should_not have_untracked_changes
      File.delete(File.join([@campaign.path, @campaign.craft.first.file_name]))
      @campaign.should have_untracked_changes
    end

    it 'should return true if there is a new craft' do 
      @campaign.should_not have_untracked_changes
      File.open("Ships/VAB/my_new_rocket.craft", "w"){|f| f.write("something new")}
      @campaign.should have_untracked_changes
    end


  end


  describe "last_changed" do 
    before(:each) do 
      set_up_sample_data
      File.open("Ships/VAB/Auto-Saved Ship.craft", 'w') {|f| f.write("some test data") }
      verify_craft_for_campaign
      commit_craft_in_campaign
      @campaign.last_changed_craft.name.should == "my_rocket_car"      
    end

    it 'should return a newly created craft ' do 
      make_new_craft_in @campaign, "VAB", "this_rocket_thing"
      verify_craft_for_campaign
      @campaign.last_changed_craft.should be_a(Craft)
      @campaign.last_changed_craft.name.should == "this_rocket_thing"
    end

    it 'should return a recently changed craft' do 
      @campaign.craft.each{|c| c.commit}
      craft = Craft.where(:name => "my_rocket").first
      change_craft_contents craft, "this craft has different content"
      @campaign.reload
      @campaign.last_changed_craft.name.should == "my_rocket"
    end

    it 'should not return a deleted craft' do 
      @campaign.craft.each{|c| c.commit}
      craft = Craft.where(:name => "my_rocket").first.update_attributes(:deleted => true)
      @campaign.reload
      @campaign.last_changed_craft.name.should_not == "my_rocket"
      @campaign.last_changed_craft.name.should == "my_rocket_car"
    end

    it 'should not return the Auto-Saved Ship as the current project' do 
      @campaign.last_changed_craft.name.should == "my_rocket_car"    
      craft = @campaign.craft.where(:name => "my_rocket").first
      auto_craft = @campaign.craft.where(:name => "Auto-Saved Ship").first
      change_craft_contents craft, "this craft has different contents"
      change_craft_contents auto_craft, "this craft was auto saved with diff contents"

      @campaign.last_changed_craft.name.should == "my_rocket"      
    end

  end

  describe "update_persistence_checksum" do 
    before(:each) do 
      @campaign = set_up_sample_data
      @digest = Digest::SHA256.file("persistent.sfs").hexdigest
    end

    it 'should update the persistence.sfs checksum' do 
      @campaign.persistence_checksum.should be_nil
      @campaign.update_persistence_checksum
      @campaign.persistence_checksum.should_not be_nil
      @campaign.persistence_checksum.should == @digest 
    end

  end

  describe "should_process?" do 
    before(:each) do 
      @campaign = set_up_sample_data
      @campaign.stub!(:discover_deleted_craft => [])      
      @campaign.verify_craft
    end

    it 'should return true on a newly created campaign' do 
      @campaign.should_process?.should be_true
    end

    it 'should return false if the persistence_checksum matches the persistent.sfs file' do 
      @campaign.update_persistence_checksum
      @campaign.should_process?.should be_false
    end

    it 'should return true again if the persistent.sfs file is changed' do 
      @campaign.update_persistence_checksum
      Dir.chdir(@campaign.path)
      File.open("persistent.sfs", 'w') {|f| f.write("this file is now changed") }
      @campaign.should_process?.should be_true
    end

    it 'should return true of the persistence_checksum is set to nil' do 
      @campaign.update_persistence_checksum
      @campaign.should_process?.should be_false
      @campaign.update_attributes(:persistence_checksum => nil)
      @campaign.should_process?.should be_true
    end

    it "should return false if the persistence_checksum is set to 'skip'" do 
      @campaign.update_attributes(:persistence_checksum => "skip")
      @campaign.should_process?.should be_false
    end

    it 'should return true if one of its craft have been deleted' do 

      @campaign.update_persistence_checksum
      @campaign.should_process?.should be_false

      File.delete("Ships/VAB/my_rocket.craft")
      @campaign.should_process?.should be_true
    end

    it 'should return true if a new craft is added' do 
      @campaign.update_persistence_checksum
      @campaign.should_process?.should be_false

      File.open("Ships/VAB/my_brand_new_rocket.craft", 'w'){|f| f.write("some new rockets stuff")}
      @campaign.should_process?.should be_true
    end

    it 'should return true if a commited craft object is deleted and then recreated with a call to veryfy craft' do 
      @campaign.update_persistence_checksum
      @campaign.should_process?.should be_false

      craft = @campaign.craft.first
      craft.destroy
      @campaign.should_process?.should be_true

      @campaign.verify_craft #will recreate the deleted craft object

      @campaign.should_process?.should be_true

    end

  end

  describe "verify_craft" do 
    before(:each) do 
      @campaign = set_up_sample_data
      @campaign.stub!(:discover_deleted_craft => [])
    end

    it 'should create a Craft model for each craft identified' do 
      Craft.count.should == 0
      @campaign.craft.should be_empty
      @campaign.verify_craft

      Craft.count.should == 3
      @campaign.reload
      @campaign.craft.size.should == 3
      @campaign.craft.select{|craft| craft.craft_type == "vab"}.size.should == 2
      @campaign.craft.select{|craft| craft.craft_type == "sph"}.size.should == 1
      @campaign.craft.map{|craft| craft.name}.sort.should == ['my_rocket', 'my_other_rocket', 'my_rocket_car'].sort
    end

    it 'should not create a new craft object if one for that name and type already exists' do 
      @campaign.verify_craft
      @campaign.craft.size.should == 3

      Dir.chdir(File.join([@campaign.path, "Ships", "SPH"]))
      File.open("my_other_rocket.craft",'w'){|f| f.write("slkjlksjfj")} #create a craft in SPH with same name as one in VAB
      @campaign.verify_craft
      @campaign.craft.size.should == 4
    end

    it 'should mark existing craft objects as deleted if the .craft file is no longer present' do 
      @campaign.verify_craft
      @campaign.craft.each{|c| c.commit}

      @campaign.craft.map{|craft| craft.deleted?}.all?.should be_false

      File.delete("Ships/VAB/my_other_rocket.craft")
      @campaign.verify_craft
      @campaign.craft.map{|craft| craft.deleted? }.all?.should be_false
      @campaign.craft.where(:craft_type => 'vab', :name => "my_other_rocket").first.deleted.should be_true
    end

    it 'should call not call discover_deleted_craft' do 
      @campaign.should_not_receive(:discover_deleted_craft)
      @campaign.verify_craft nil
    end
    it 'should call discover_deleted_craft when instructed to' do 
      @campaign.should_receive(:discover_deleted_craft).once.and_return([])
      @campaign.verify_craft nil, :discover_deleted => true
    end
  end


  describe "discover already deleted craft" do 
    before(:each) do 
      set_up_sample_data
      @campaign.create_repo
      repo = @campaign.repo

      repo.add("Ships/VAB/my_rocket.craft")
      repo.commit("added my_rocket")
      repo.add("Ships/VAB/my_other_rocket.craft")
      repo.commit("added my_other_rocket")

      repo.add("Ships/SPH/my_rocket_car.craft")
      repo.commit("added my_rocket_car")

    end

    it 'should do return an array containing details about deleted craft' do     
      repo = @campaign.repo
      File.delete("Ships/VAB/my_rocket.craft")
      repo.remove("Ships/VAB/my_rocket.craft")
      repo.commit("removed my_rocket")     
      File.delete("Ships/VAB/my_other_rocket.craft")
      repo.remove("Ships/VAB/my_other_rocket.craft")
      repo.commit("removed my_other_rocket")     

      discovered = @campaign.discover_deleted_craft
      discovered.size.should == 2
      discovered[0][:deleted][0][:name].should == "my_other_rocket.craft"
      discovered[0][:deleted][0][:craft_type].should == "VAB"
      discovered[1][:deleted][0][:name].should == "my_rocket.craft"
      discovered[1][:deleted][0][:craft_type].should == "VAB"

    end

    it 'should not include details if the deleted craft has a Craft object' do 
      repo = @campaign.repo
      @craft = @campaign.craft.create!(:name => "my_rocket", :craft_type => :vab)
      @craft.history.size.should == 1
      @craft.update_history_count

      File.delete("Ships/VAB/my_rocket.craft")
      @craft.deleted = true
      @craft.commit   

      File.delete("Ships/VAB/my_other_rocket.craft")
      repo.remove("Ships/VAB/my_other_rocket.craft")
      repo.commit("removed my_other_rocket")     

      discovered = @campaign.discover_deleted_craft

      discovered.size.should == 1
      discovered[0][:deleted].size.should == 1
      discovered[0][:deleted][0][:name].should == "my_other_rocket.craft"
      discovered[0][:deleted][0][:craft_type].should == "VAB"

    end

    it 'should return details of deleted craft that where deleted in the same commit' do 
      repo = @campaign.repo
      File.delete("Ships/VAB/my_rocket.craft")
      File.delete("Ships/VAB/my_other_rocket.craft")
      repo.remove("Ships/VAB/my_rocket.craft")
      repo.remove("Ships/VAB/my_other_rocket.craft")
      repo.commit("removed my_other_rocket")     

      discovered = @campaign.discover_deleted_craft
      discovered.size.should == 1
      discovered[0][:deleted][0][:name].should == "my_other_rocket.craft"
      discovered[0][:deleted][0][:craft_type].should == "VAB"
      discovered[0][:deleted][1][:name].should == "my_rocket.craft"
      discovered[0][:deleted][1][:craft_type].should == "VAB"
    end


  end


  describe "present?" do 
    before(:each) do 
      @campaign = set_up_sample_data
    end

    it 'should return true if the campaign directory is present' do 
      @campaign.exists?.should be_true
    end

    it 'should return false if the campaign directory has been removed' do 
      Dir.chdir Rails.root
      FileUtils.rm_rf "temp_test_dir/KSP_test/saves/#{@campaign.name}"
      @campaign.exists?.should be_false
    end

  end

  describe "flag_path" do 
    before(:each) do 
      @campaign = set_up_sample_data
    end

    it 'should return the flag file set in the persistent file' do 
      File.open("persistent.sfs",'w'){|f| f.write persistent_file_without_craft}
      @campaign.path_to_flag.should == "#{@instance.path}/GameData/Katateochi/Flags/my_flag.png"
    end

    it 'should return nil if no flag is defined in persistent file' do 
      @campaign.path_to_flag.should be_nil
    end


  end

  describe "save tracking" do 

    describe "track save" do 
      before(:each) do 
        @campaign = set_up_sample_data
      end

      describe "quicksave" do 
        it 'should add the quicksave.sfs file to the repo with a commit message that saying that quicksave.sfs was added' do 
          @campaign.repo.untracked.should be_include("quicksave.sfs")
          @campaign.track_save :quicksave
          @campaign.repo.untracked.should_not be_include("quicksave.sfs")
          @campaign.repo.log.first.message.should == "added quicksave.sfs"
        end

        it 'should update the quicksave.sfs file in the repo if it has changed with a commit message that saying that quicksave.sfs was updated' do 
          @campaign.track_save :quicksave
          File.open("quicksave.sfs", 'w'){|f| f.write("not the save it was before")}
          @campaign.repo.changed.should be_include("quicksave.sfs")
          @campaign.track_save :quicksave
          @campaign.repo.changed.should_not be_include("quicksave.sfs")
          @campaign.repo.untracked.should_not be_include("quicksave.sfs")
          @campaign.repo.log.first.message.should == "updated quicksave.sfs"
        end
      end

      describe "persistent" do 
        it 'should add the persistent.sfs file to the repo with a commit message that saying that persistent.sfs was added' do 
          @campaign.repo.untracked.should be_include("persistent.sfs")
          @campaign.track_save :persistent
          @campaign.repo.untracked.should_not be_include("persistent.sfs")
          @campaign.repo.log.first.message.should == "added persistent.sfs"
        end

        it 'should update the persistent.sfs file in the repo if it has changed with a commit message that saying that persistent.sfs was updated' do 
          @campaign.track_save :persistent
          File.open("persistent.sfs", 'w'){|f| f.write("not the save it was before")}
          @campaign.repo.changed.should be_include("persistent.sfs")
          @campaign.track_save :persistent
          @campaign.repo.changed.should_not be_include("persistent.sfs")
          @campaign.repo.untracked.should_not be_include("persistent.sfs")
          @campaign.repo.log.first.message.should == "updated persistent.sfs"
        end
      end

      it 'should set a custom commit message if one is supplied' do 
        @campaign.track_save :quicksave, :message => "and all was good"
        @campaign.repo.log.first.message.should == "and all was good"
      end

      it 'should track both if given :both instead of :quicksave or :persistent' do 
        @campaign.repo.untracked.should be_include("quicksave.sfs")
        @campaign.repo.untracked.should be_include("persistent.sfs")
        @campaign.track_save :both
        @campaign.repo.untracked.should_not be_include("quicksave.sfs")
        @campaign.repo.untracked.should_not be_include("persistent.sfs")
      end

    end

    describe "save history" do 
      before(:each) do 
        @campaign = set_up_sample_data
      end

      it 'should return empty hash when no saves are tracked' do 
        @campaign.repo.untracked.should be_include("quicksave.sfs")
        @campaign.repo.untracked.should be_include("persistent.sfs")
        @campaign.save_history.should == {}
      end

      it 'should contain keys for quicksave when it is tracked' do 
        @campaign.track_save :quicksave
        @campaign.save_history.keys.should be_include(:quicksave)
      end
      it 'should contain keys for persistent when it is tracked' do 
        @campaign.track_save :persistent
        @campaign.save_history.keys.should be_include(:persistent)
      end

      it 'should have an array of commits for each save' do 
        @campaign.track_save :both
        @campaign.save_history[:quicksave].should be_a(Array)
        @campaign.save_history[:persistent].should be_a(Array)
        @campaign.save_history[:quicksave].size.should == 1
        @campaign.save_history[:persistent].size.should == 1

        File.open("persistent.sfs", 'w'){|f| f.write("not the save it was before")}
        File.open("quicksave.sfs", 'w'){|f| f.write("not the save it was before")}
        @campaign.track_save :both

        @campaign.save_history[:quicksave].size.should == 2
        @campaign.save_history[:persistent].size.should == 2
      end

    end

  end

  describe "revert saves" do 
    before(:each) do 
      @campaign = set_up_sample_data
      @campaign.track_save :both
      File.open("persistent.sfs", 'w'){|f| f.write("not the save it was before")}
      File.open("quicksave.sfs", 'w'){|f| f.write("not the save it was before")}
      @campaign.track_save :both
    end

    it 'should revert a save to a previous commit' do 
      current_file = File.open("quicksave.sfs", 'r'){|f| f.readlines}.join
      current_file.should == "not the save it was before"

      commit = @campaign.save_history[:quicksave][1]
      @campaign.revert_save :quicksave, commit, :commit => true

      reverted_file = File.open("quicksave.sfs", 'r'){|f| f.readlines}.join
      reverted_file.should == "some test data"
    end

  end

  describe "persistent_to_quicksave" do 
    before(:each) do 
      @campaign = set_up_sample_data
      @campaign.track_save :both
      File.open("persistent.sfs", 'w'){|f| f.write("this is the persistent file")}
      File.open("quicksave.sfs", 'w'){|f| f.write("this is the quicksave file")}
      @campaign.track_save :both
    end

    it 'should overwrite the quicksave with the contents of the persistent file' do 
      @campaign.persistent_to_quicksave
      reverted_file = File.open("quicksave.sfs", 'r'){|f| f.readlines}.join
      reverted_file.should == "this is the persistent file"
    end

  end


  describe "latest_Commit" do 
    before(:each) do 
      @campaign = set_up_sample_data      
    end

    it 'should be :current_project if nothing has been commited' do 
      @campaign.latest_commit.should == :current_project
    end

    it 'should return quicksave if it was the most recent commit' do 
      System.process
      @campaign.track_save :quicksave
    
      sleep(1) #so there is a difference on the commit timestamp
      File.open("quicksave.sfs", 'w'){|f| f.write("this is the quicksave file I think")}
      System.process    
      @campaign.reload.latest_commit.should == :quicksave
    end


    it 'should return :current_project if it is editied (by not commited) after the quicksave' do 
      System.process
      @campaign.track_save :quicksave
      sleep(1) #so there is a difference on the commit timestamp
      File.open("quicksave.sfs", 'w'){|f| f.write("this is the quicksave file I think")}
      System.process          
      @campaign.reload.latest_commit.should == :quicksave
      
      File.open(@campaign.craft.first.file_name, 'w'){|f| f.write("craft change")}
      @campaign.reload.latest_commit.should == :current_project
    end

    it 'should return :current_project if it commited after the quicksave' do 
      System.process
      @campaign.track_save :quicksave
      sleep(1) #so there is a difference on the commit timestamp
      File.open("quicksave.sfs", 'w'){|f| f.write("this is the quicksave file I think")}
      System.process          
      @campaign.reload.latest_commit.should == :quicksave
      
      File.open(@campaign.craft.first.file_name, 'w'){|f| f.write("craft change")}
      @campaign.craft.first.commit
      @campaign.reload.latest_commit.should == :current_project
    end

  end

  
  describe "dont_process_while" do 
    before(:each) do 
      @campaign = set_up_sample_data
    end

    it "should set the campaigns persistent_checksum to 'skip' while the block is being called" do 
      @campaign.update_persistence_checksum
      @campaign.persistence_checksum.should_not be_nil
      @campaign.dont_process_while do 
        @campaign.reload.persistence_checksum.should == "skip"
      end
      @campaign.reload.persistence_checksum.should_not == "skip"
    end


  end
end
