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
    files = git "diff --name-only HEAD"
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
    #git "reset \"#{file}\"" #call reset so the reverted file is unstaged which is needed to it be detected as changed.
  end

  def checkout options
    git "checkout #{options}"
  end

  def branch branch_name
    git "branch #{branch_name}"
  end

  #remove a given file from the repo
  def remove file
    git "rm \"#{file}\""
  end

  #return a commit object for a given sha_id. Slow in repos with large numbers of commits
  def gcommit sha_id
    #self.log(sha_id).first
    logs = git "log #{sha_id}"
    read_log(logs).first
  end

  #performs similar function to gcommit, but faster and for specific file path
  #given a file path it attempts to find the commit for the given sha_id in the 5 most recent commits
  #otherwise it looks in all commits for that file.  Faster that gcommit which looks in the entire repo.
  def get_commit args = {}
    #attempt to find commit for given path in the 5 most recent commits
    commit = self.log(args[:for], :limit => 10).select{|c| c.to_s == args[:sha_id]}.first
    #if above didn't find it, attempt to find in all commits for given path
    commit ||= self.log(args[:for]).select{|c| c.to_s == args[:sha_id]}.first

    commit
  end

  #call git GC, to run gits garbage collector and compress the repo
  def gc
    git "gc"
  end

  def rebase opts
    git "rebase #{opts}"
  end

  def filter_branch opts  
    git "filter-branch #{opts}"
  end

  #call git log on the repo, either 
  #- for the entire repo (if no args given)               - repo.log
  #- for a given file                                     - repo.log(<file_name>)
  #- for the entire repo but limited to a certain number  - repo.log(:limit => 4)
  #- for a file but limited to a certain number           - repo.log(<file_name>, :limit => 4)
  def log file = nil, args = {}
    #enable args to be passed as first arg, if no file is given. or passed as second arg if a file is given
    args, file = file, nil if file.is_a?(Hash) 
  
    command = "log" #base command
    command << " -n #{args[:limit].to_i}" if args[:limit] #append limit arg -n x, if args[:limit] is given
    command << " -- \"#{file}\"" if file   #append filename if file is given
    logs = git command   #run git command
    read_log logs   #send raw log string to be processed into separate Commit objects
  end

  def status
    git "status"
  end

  def do command
    git command
  end

  private

  #pass commands to git.  git will be called from the directory given to the instance of Repo
  #usage: git <command>
  # ie: git "status"
  def git command
    in_repo_dir {`git #{command}` }
  end

  #Run a block in the dir given to repo as @path
  #takes block, changes into dir in @path and then returns to what ever dir 
  #it was previously in.
  def in_repo_dir &blk
    cur_dir = Dir.getwd
    Dir.chdir(@path)
    action = yield
    Dir.chdir(cur_dir)
    action = "" if action.nil? #ensure that a sting is retuned 
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
