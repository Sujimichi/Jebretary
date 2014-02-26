require 'spec_helper'

def do_several_commits
  `git add persistent.sfs`        
  `git commit -m "added persistent file"` 

  `git add Ships/VAB/my_other_rocket.craft`
  `git commit -m "added my other rocket"` 

  File.open("Ships/VAB/my_rocket.craft", 'w') {|f| f.write("first version") }
  `git add Ships/VAB/my_rocket.craft`
  `git commit -m "commited first version"` 
  File.open("Ships/VAB/my_rocket.craft", 'w') {|f| f.write("second version") }
  `git add Ships/VAB/my_rocket.craft`
  `git commit -m "commited second version"` 
  File.open("Ships/VAB/my_rocket.craft", 'w') {|f| f.write("third version") }
  `git add Ships/VAB/my_rocket.craft`
  `git commit -m "commited third version"` 
end


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
      `touch .gitignore`
      `git add .gitignore`
      `git commit -m "ignore me"`
    end

    it 'should list untracked files' do  
      repo = Repo.new(@path)
      repo.untracked.should == ["Ships/SPH/my_rocket_car.craft", "Ships/VAB/my_other_rocket.craft", "Ships/VAB/my_rocket.craft", "persistent.sfs", "quicksave.sfs"]    
    end

    it 'should not include files that are tracked' do 
      `git add persistent.sfs`
      `git commit -m "added pfile"`
      `git add Ships/VAB/my_other_rocket.craft`
      `git commit -m "added a rocket"`

      repo = Repo.new(@path)
      repo.untracked.should == ["Ships/SPH/my_rocket_car.craft", "Ships/VAB/my_rocket.craft", "quicksave.sfs"]    
    end

    it 'should not include files that are changed'  do 
      `git add Ships/VAB/my_other_rocket.craft`
      `git commit -m "added a rocket"`
      File.open("Ships/VAB/my_other_rocket.craft", 'w') {|f| f.write("something different") }

      repo = Repo.new(@path)
      repo.untracked.should == ["Ships/SPH/my_rocket_car.craft", "Ships/VAB/my_rocket.craft", "persistent.sfs", "quicksave.sfs"]    
    end
  end


  describe "add" do 
    before(:each) do 
      Dir.chdir(@path)
      `git init`

      `git add persistent.sfs`        #this is added and commited so the repo has an initial commit, 
      `git commit -m "inital commit"` #needed in order to make the git diff asertion line work
    end

    it 'should stage a new file to HEAD' do
      repo = Repo.new(@path)      
      repo.untracked.should be_include "quicksave.sfs"
      repo.tracked.should == ["persistent.sfs"]
     
      repo.add "quicksave.sfs"
      `git diff --name-only HEAD`.should be_include "quicksave.sfs"
    end

    it 'should add a modified file to stage' do
      repo = Repo.new(@path)      
      `git add Ships/VAB/my_other_rocket.craft`        
      `git commit -m "added my_other_rocket"` 

      `git diff --name-only HEAD`.should_not be_include "Ships/VAB/my_other_rocket.craft"

      File.open("Ships/VAB/my_other_rocket.craft", 'w') {|f| f.write("something different") }
      repo.add "Ships/VAB/my_other_rocket.craft"
      `git diff --name-only HEAD`.should be_include "Ships/VAB/my_other_rocket.craft"
    end
  end

  describe "commit" do 
    before(:each) do 
      Dir.chdir(@path)
      `git init`
      `git add persistent.sfs`        #this is added and commited so the repo has an initial commit, 
      `git commit -m "inital commit"` #needed in order to make the git log asertion line work without throwing a warning - fatal: bad default revision 'HEAD
      `git add Ships/VAB/my_rocket.craft`
    end

    it 'should commit staged files to the repo with a message' do 
      `git log`.should_not be_include "my rocket"
      repo = Repo.new(@path)      
      repo.tracked.should_not be_include "Ships/VAB/my_rocket.craft"         

      repo.commit "added my rocket"

      `git log`.should be_include "added my rocket"
      repo.tracked.should be_include "Ships/VAB/my_rocket.craft"         
    end

    describe "odd symbols in commit messages" do 
      before(:each) do 
        @repo = Repo.new(@path)      
      end

      it "should allow ' in commit message" do      
        @repo.commit "added my rocket's"
        `git log`.should be_include "added my rocket's"
      end

      it 'should allow ! in commit message' do      
        @repo.commit "added my rocket!!"
        `git log`.should be_include "added my rocket!!"
      end

      it 'should allow \n in commit message' do      
        @repo.commit "added my rocket\nfoo"
        `git log`.should be_include "added my rocket\n    foo" #the space is introduced by the way log displays the output
      end

    end
  end

  describe "log" do 
    before(:each) do 
      Dir.chdir(@path)
      `git init`
      do_several_commits
      @repo = Repo.new(@path)
    end

    it 'should return all the logs for the repo as commit objects' do 
      @repo.log.size.should == 5
      @repo.log.map{|log| log.is_a?(Repo::Commit) }.all?.should be_true
    end

    it 'should return a limited set of reports given optional arg' do 
      @repo.log(:limit => 2).size.should == 2
    end

    it 'should return all logs if nil or false is passed as the limit' do 
      @repo.log(:limit => nil).size.should == 5
      @repo.log(:limit => false).size.should == 5
    end

    it 'should return the commits with the newest one first' do 
      @repo.log.last.message.should == "added persistent file"
      @repo.log.first.message.should == "commited third version"
    end 
  end

  describe "fetching commits for a file" do 
    before(:each) do 
      Dir.chdir(@path)
      `git init`
      do_several_commits

      File.open("Ships/VAB/my_other_rocket.craft", 'w') {|f| f.write("something different") }
      `git add Ships/VAB/my_other_rocket.craft`
      `git commit -m "updated my other rocket\nit was a blast"` 

    end

    it 'should return commit objects for each commit of a given file' do 
      repo = Repo.new(@path)      
      repo.log("persistent.sfs").should be_a(Array)
      repo.log("persistent.sfs").size.should == 1
      repo.log("persistent.sfs").first.should be_a(Repo::Commit)

      repo.log("Ships/VAB/my_rocket.craft").size.should == 3
      repo.log("Ships/VAB/my_other_rocket.craft").size.should == 2
    end

    it 'should take a optional second arg to limit the number of commits retunred' do 
      repo = Repo.new(@path)      
      repo.log("Ships/VAB/my_rocket.craft", :limit => 1).size.should == 1
      repo.log("Ships/VAB/my_rocket.craft", :limit => 1).first.message.should == "commited third version"
    end


    describe "commits" do 
      before(:each) do 
        @repo = Repo.new(@path)      
      end

      it 'should return a sha_id' do 
        sha_id = `git log persistent.sfs`.split("\n").first.sub("commit ","")
        commit = @repo.log("persistent.sfs").first  
        commit.sha_id.should == sha_id
      end

      it 'should return the commit message' do 
        commit = @repo.log("Ships/VAB/my_other_rocket.craft").first
        commit.message.should == "updated my other rocket\nit was a blast"
      end

    end
  end


  describe "checkout_file" do 
    before(:each) do 
      Dir.chdir(@path)
      `git init`
      do_several_commits
      @repo = Repo.open(@path)      
    end

    it 'should return a file to a previous state' do 
      
      File.open("Ships/VAB/my_rocket.craft", 'r') {|f| f.readlines }.join.should == "third version"

      commit = @repo.log("Ships/VAB/my_rocket.craft").last
      @repo.checkout_file commit, "Ships/VAB/my_rocket.craft"
      File.open("Ships/VAB/my_rocket.craft", 'r') {|f| f.readlines }.join.should == "first version"

      commit = @repo.log("Ships/VAB/my_rocket.craft")[1]
      @repo.checkout_file commit, "Ships/VAB/my_rocket.craft"
      File.open("Ships/VAB/my_rocket.craft", 'r') {|f| f.readlines }.join.should == "second version"
    end

  end

  describe "checkout" do 
    before(:each) do 
      Dir.chdir(@path)
      `git init`
      do_several_commits
      @repo = Repo.open(@path)      
      `git branch`.should.eql?("* master\n")
    end  

    it 'should enable switching to a new branch' do 
      @repo.checkout "-b my_new_branch"
      `git branch`.should.eql?("  master\n* my_new_branch\n")
    end

    it 'should enable creating a new branch from a specific commit' do 
      commit = @repo.log[4]
      message = commit.message

      @repo.checkout "#{commit} -b my_new_branch"
      `git branch`.should.eql?("  master\n* my_new_branch\n")
      @repo.log.first.message.should == message
    end

    it 'should enable switching to a different branch' do 
      `git checkout -b temp_branch`
      `git branch`.should.eql?("  master\n* temp_branch\n")

      @repo.checkout "master"
      `git branch`.should.eql?("* master\n  temp_branch\n")
    end
  end

  describe "branch" do 
    before(:each) do 
      Dir.chdir(@path)
      `git init`
      do_several_commits
      @repo = Repo.open(@path)      
      `git branch`.should.eql?("* master\n")
    end  

    it 'should enable deleting a branch' do 
      `git checkout -b temp_branch`
      `git checkout master`
      `git branch`.should.eql?("* master\n  temp_branch\n")

      @repo.branch "temp_branch -D"
      `git branch`.should.eql?("* master\n")
    end

  end

  describe "gcommit" do 
    before(:each) do 
      Dir.chdir(@path)
      `git init`
      do_several_commits
      @repo = Repo.open(@path)
    end
    
    it 'should find a commit object for a given sha_id' do 
      commit = @repo.log[3]
      sha_id = commit.sha_id
      message = commit.message

      @repo.gcommit(sha_id).should be_a Repo::Commit
      @repo.gcommit(sha_id).sha_id.should == sha_id
      @repo.gcommit(sha_id).message.should == message
    end

    it 'should not have a cow if the sha_id cant be found' do 
      @repo.gcommit("lskjldkjf").should be_nil
    end

  end

  describe "remove" do 
    before(:each) do 
      Dir.chdir(@path)
      `git init`
      do_several_commits
      @repo = Repo.open(@path)      
    end

    it 'should remove a file' do 
      Dir.glob("#{@path}/**/*.*").map{|f| f.sub("#{@path}/", "")}.should be_include "Ships/VAB/my_rocket.craft"
      @repo.remove "Ships/VAB/my_rocket.craft"

      Dir.glob("#{@path}/**/*.*").map{|f| f.sub("#{@path}/", "")}.should_not be_include "Ships/VAB/my_rocket.craft"
    end
    
  end

end
