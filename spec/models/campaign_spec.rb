require 'spec_helper'


describe Campaign do

  describe "creating a git repo" do 
    before(:each) do 
      set_up_sample_data
    end

    it 'should create a new repo if none exists' do 
      #Git.should_receive(:init).and_return(Git.init(@c.path))
      Dir.entries(@c.path).sort.should == ["persistent.sfs", "Ships", "quicksave.sfs", ".", ".."].sort
      @c.create_repo
      Dir.entries(@c.path).should contain('.git')
    end

    it 'should add a .gitignore to the repo' do 
      @c.create_repo
      g = Git.open(@c.path)
      Dir.entries(@c.path).should contain('.git')
      g.log.object(".gitignore").should be_a Git::Log
      g.log.object(".gitignore").should_not contain("unknown revision or path")
    end


    it 'should not attempt to create if repo already exists' do 
      @c.create_repo
      g = Git.open(@c.path)

      Git.should_not_receive(:init)
      @c.create_repo
    end

  end

  describe "commit craft" do 
    before(:each) do 
      set_up_sample_data
      @c.create_repo
    end

    it 'should commit existing craft files to repo (assuming run first time with craft already present)' do 
      g = Git.open(@c.path)
      g.status["Ships/VAB/my_rocket.craft"].untracked.should be_true
      @c.commit_craft
      g.status["Ships/VAB/my_rocket.craft"].untracked.should be_false
      g.log.object("Ships/VAB/my_rocket.craft").should be_a Git::Log
      g.log.object("Ships/VAB/my_rocket.craft").should_not contain("unknown revision or path")
    end

    it 'should put the added craft names in the commit message' do 
      @c.commit_craft
      g = Git.open(@c.path)
      message = g.object(g.log.to_a[0]).message
      message.should == "Added craft: SPH/my_rocket_car.craft, VAB/my_other_rocket.craft, VAB/my_rocket.craft" 
    end

    it 'should put the updated craft names in the commit message' do 
      @c.commit_craft
      File.open('Ships/VAB/my_rocket.craft', 'w'){|f| f.write("changed content*") }
      @c.commit_craft
      g = Git.open(@c.path)
      message = g.object(g.log.to_a[0]).message
      message.should == "Updated craft: VAB/my_rocket.craft" 
    end

    it 'should add and commit new craft files to repo (assuming some craft already present)' do 
      g = Git.open(@c.path)
      Dir.chdir("#{@c.path}/Ships/VAB")
      File.open('my_brand_new_fast_as_fuck_rocket.craft', 'w'){|f| f.write("some test data")}
      g.status["Ships/VAB/my_brand_new_fast_as_fuck_rocket.craft"].untracked.should be_true
      @c.commit_craft
      g.status["Ships/VAB/my_brand_new_fast_as_fuck_rocket.craft"].untracked.should be_false
      g.log.object("Ships/VAB/my_brand_new_fast_as_fuck_rocket.craft").should be_a Git::Log
      g.log.object("Ships/VAB/my_brand_new_fast_as_fuck_rocket.craft").should_not contain("unknown revision or path")
    end


  end

  describe "commit saves" do
    before(:each) do 
      set_up_sample_data
      @c.create_repo
    end

    it 'should add save files' do 
      g = Git.open(@c.path)
      g.status["persistent.sfs"].untracked.should be_true
      g.status["quicksave.sfs"].untracked.should be_true

      @c.commit_saves
      g.status["persistent.sfs"].untracked.should be_false
      g.status["quicksave.sfs"].untracked.should be_false
    end

    it "should put 'added quicksave and persistent save files' in the message first time round" do 
      g = Git.open(@c.path)
      @c.commit_saves
      message = g.object(g.log.to_a[0]).message
      message.should == "Added quicksave and persistent save files"
    end

    it "should put 'updated quicksave and persistent save files' in the message when both are changed" do 
      g = Git.open(@c.path)
      @c.commit_saves
      File.open('persistent.sfs', 'w'){|f| f.write("changed p file")}
      File.open('quicksave.sfs', 'w'){|f| f.write("changed qs file")}

      @c.commit_saves
      message = g.object(g.log.to_a[0]).message
      message.should == "Updated quicksave and persistent save files"
    end

    it "should put 'Updated quicksave file' when just updating the quicksave" do
      g = Git.open(@c.path)
      @c.commit_saves
      File.open('quicksave.sfs', 'w'){|f| f.write("changed qs file")}
      @c.commit_saves
      message = g.object(g.log.to_a[0]).message
      message.should == "Updated quicksave file"
    end

    it "should put 'Updated persistent file' when just updating the persistent file" do
      g = Git.open(@c.path)
      @c.commit_saves
      File.open('persistent.sfs', 'w'){|f| f.write("changed p file")}
      @c.commit_saves
      message = g.object(g.log.to_a[0]).message
      message.should == "Updated persistent file"
    end
    

  end


end
