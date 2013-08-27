require 'spec_helper'


describe Campaign do

  describe "creating a git repo" do 
    before(:each) do 
      set_up_sample_data
    end

    it 'should create a new repo if none exists' do 
      #Git.should_receive(:init).and_return(Git.init(@campaign.path))
      Dir.entries(@campaign.path).sort.should == ["persistent.sfs", "Ships", "quicksave.sfs", ".", ".."].sort
      @campaign.create_repo
      Dir.entries(@campaign.path).should contain('.git')
    end

    it 'should add a .gitignore to the repo' do 
      @campaign.create_repo
      g = Git.open(@campaign.path)
      Dir.entries(@campaign.path).should contain('.git')
      g.log.object(".gitignore").should be_a Git::Log
      g.log.object(".gitignore").should_not contain("unknown revision or path")
    end


    it 'should not attempt to create if repo already exists' do 
      @campaign.create_repo
      g = Git.open(@campaign.path)
      Git.should_not_receive(:init)
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


  describe "last_changed" do 
    before(:each) do 
      set_up_sample_data
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

  end

  describe "verify_craft" do 
    before(:each) do 
      @campaign = set_up_sample_data
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
      Dir.chdir("SPH")
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
  end
   

end
