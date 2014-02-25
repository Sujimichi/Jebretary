require 'spec_helper'

describe Repo do
  before(:each) do 
    set_up_sample_data
    @path = Rails.root.join("temp_test_dir", "KSP_test", "saves", "test_campaign")
  end

  describe "git_init" do 
    it 'should create a git repo' do 
      Dir.entries(@path).should_not be_include(".git")
      repo = Repo.new(@path)
      repo.git_init
      Dir.entries(@path).should be_include(".git")     
    end

  end

  describe "Repo.open" do 
    it 'should create a repo if one did not exists and return the repo object' do 
      Dir.entries(@path).should_not be_include(".git")
      repo = Repo.open(@path)
      Dir.entries(@path).should be_include(".git")
      repo.should be_a Repo
    end

    it 'should not create a repo if one already exists, just return the repo object' do 
      #setup repo
      Dir.chdir(@path)
      `git init`
      Dir.entries(@path).should be_include(".git")
    
      r = Repo.new(@path)
      r.should_not_receive :git_init
      Repo.stub!(:new => r)
      repo = Repo.open(@path)
    end
  end


  describe "tracked" do 
    before(:each) do 
      Dir.chdir(@path)
      `git init`
      `git add persistent.sfs`
      `git commit -m "added pfile"`
      `git add Ships/VAB/my_other_rocket.craft`
      `git commit -m "added a rocket"`
    end

    it 'should list tracked files' do 
      repo = Repo.new(@path)
      repo.tracked.should == ["Ships/VAB/my_other_rocket.craft", "persistent.sfs"]    
    end

    it 'should include changed files' do 
      File.open("Ships/VAB/my_other_rocket.craft", 'w') {|f| f.write("something different") }

      repo = Repo.new(@path)
      repo.tracked.should == ["Ships/VAB/my_other_rocket.craft", "persistent.sfs"]    
    end


  end  

  describe "changed" do 
    before(:each) do 
      Dir.chdir(@path)
      `git init`
      `git add persistent.sfs`
      `git commit -m "added pfile"`
      `git add Ships/VAB/my_other_rocket.craft`
      `git commit -m "added a rocket"`     
    end

    it 'should be empty if no files are changed' do 
      repo = Repo.new(@path)
      repo.changed.should be_empty
    end

    it 'should list files that are tracked and also changed' do 
      File.open("Ships/VAB/my_other_rocket.craft", 'w') {|f| f.write("something different") }

      repo = Repo.new(@path)
      repo.changed.should == ["Ships/VAB/my_other_rocket.craft"]    
    end
  end

  describe "untracked" do 
    before(:each) do 
      Dir.chdir(@path)
      `git init`
    end

    it 'should list untracked files' do  
      repo = Repo.new(@path)
      repo.untracked.should == ["Ships/VAB/my_other_rocket.craft", "Ships/VAB/my_rocket.craft", "Ships/SPH/my_rocket_car.craft", "persistent.sfs", "quicksave.sfs"]    
    end

    it 'should not include files that are tracked' do 
      `git add persistent.sfs`
      `git commit -m "added pfile"`
      `git add Ships/VAB/my_other_rocket.craft`
      `git commit -m "added a rocket"`

      repo = Repo.new(@path)
      repo.untracked.should == ["Ships/VAB/my_rocket.craft", "Ships/SPH/my_rocket_car.craft", "quicksave.sfs"]    
    end

    it 'should not include files that are changed'  do 
      `git add Ships/VAB/my_other_rocket.craft`
      `git commit -m "added a rocket"`
      File.open("Ships/VAB/my_other_rocket.craft", 'w') {|f| f.write("something different") }

      repo = Repo.new(@path)
      repo.untracked.should == ["Ships/VAB/my_rocket.craft", "Ships/SPH/my_rocket_car.craft", "persistent.sfs", "quicksave.sfs"]    
    end
  end
end
