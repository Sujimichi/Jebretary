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
      @campaign.create_repo      
      Craft.verify_craft_for @campaign
      @campaign.reload.craft.each{|c| c.commit}
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

  end


end
