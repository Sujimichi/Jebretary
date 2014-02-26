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
  def self.init path
    Repo.open(path)
  end
              

  #initialize git repo
  def git_init
    git "init"
  end

  #list all files that are tracked by the repo
  def tracked
    files = git "ls-tree -r master --name-only"
    files.split("\n") #using split("\n") rather than .each_line.to_a as split is slightly faster (10th of a second over 50000 runs)
  end

  #list all files that have been modified 
  def changed
    files = git "diff --name-only"
    files.split("\n")
  end

  #list all files that are not yet tracked by the repo
  def untracked
    files = git "ls-files --other --exclude-standard"
    files.split("\n")
  end

  #stage files 
  def add files
    git "add \"#{files}\""
  end

  #commit to repo
  def commit message
    git "commit -m \"#{message}\""
  end

  def checkout_file commit, file
    commit = commit.sha_id if commit.is_a?(Commit)
    git "checkout #{commit} \"#{file}\""
  end

  #untested
  def checkout options
    git "checkout #{options}"
  end

  #untested
  def branch branch_name
    git "branch #{branch_name}"
  end

  def remove file
    git "rm \"#{file}\""
  end

  def gcommit sha_id
    self.log(sha_id).first
  end

  def log file = nil
    if file
      log = git "log \"#{file}\""
    else
      log = git "log"
    end
    read_log log
  end

  def status
    git "status"
  end

  def do command
    git command
  end

  #private

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

  def read_log log
    log = log.split("\n") #split the log (with an axe) into lines
    commit_lines = log.select{|l| l.match(/^(commit)/)} #select the lines which start with "commit"   
    indexes = commit_lines.map{|line| log.index(line) } #index the commit lines to get the starting line for each commit

    #get indexes for the start and end lines for each commit
    start_end_lines = []
    indexes.each_with_index{|v,i| 
      unless i == indexes.size - 1
        start_end_lines << [v,indexes[i+1] - 1 ] 
      else
        start_end_lines << [v,log.size ] 
      end
    }

    start_end_lines.map do |start, stop|
      Commit.new(log[start..stop], @path)
    end  
  end

end


class Repo::Commit
  attr_accessor :raw_data

  def initialize raw_commit_data, repo_path
    @raw_data = raw_commit_data
    @path = repo_path
  end

  def sha_id
    @raw_data[0].sub("commit ", "")
  end

  def to_s
    sha_id
  end

  def message
    lines = @raw_data[4..@raw_data.size-1].map{|line| line.sub(/^(\s{4})/, "")}
    lines.pop if lines.last.empty?
    lines.join("\n")
  end

  #untested
  def parent
    repo = Repo.new(@path)
    repo.send("git", "rev-list --parents -n 1 #{sha_id}").split.last
  end

  def date
    @raw_data[2].sub("Date:   ", "").to_datetime
  end

end
