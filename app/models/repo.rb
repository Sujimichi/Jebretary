class Repo

  def initialize path
    @path = path
  end

  #given a path, it will initialize a git repo if one does not exists
  #then return an instance of repo 
  def self.open path
    repo = Repo.new(path)
    repo.git_init unless Dir.entries(path).include?(".git")
    repo
  end

  #initialize git repo
  def git_init
    git "init"
  end

  #list all files that are tracked by the repo
  def tracked
    files = git "ls-tree -r master --name-only"
    files.split("\n")
  end

  #list all files that have been modified 
  def changed
    changed = git "diff --name-only"
    changed.split("\n")
  end

  #list all files that are not yet tracked by the repo
  def untracked
    all_files = Dir.glob(File.join([@path, "**", "*.*"])).map{|file| file.sub("#{@path.to_s}/", "")}
    untracked = all_files - tracked - changed
  end


  def log
    git "log"
  end

  def status
    git "status"
  end

  private

  #pass commands to git.  git will be called from the directory given to the instance of Repo
  #usage: git <command>
  # ie: git "status"
  def git command
    in_repo_dir do
      `git #{command}`
    end
  end

  #Run a block in the dir given to repo as @path
  #takes block, changes into dir in @path and then returns to what ever dir 
  #it was previously in.
  def in_repo_dir &blk
    cur_dir = Dir.getwd
    Dir.chdir(@path)
    action = yield
    Dir.chdir(cur_dir)
    return action
  end

end
