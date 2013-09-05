class Craft < ActiveRecord::Base
  attr_accessible :name, :craft_type, :deleted, :part_count, :history_count, :last_commit, :commit_message
  belongs_to :campaign

  require 'active_support/builder'

  validates :commit_message, :is_git_compatible => true

  #
  ## - Instance Methods
  ###

  #retun the path to the .craft file, form the root of the repo.
  def file_name
    "Ships/#{craft_type.upcase}/#{name}.craft"
  end

  #to be repalced with attribute to enable optional tracking of craft.
  def track?
    true
  end

  #crafts_campaign= allows the campaign to be passed in and held in instance var if the campaign has already been loaded from the DB
  def crafts_campaign= campaign
    @campaign = campaign
  end

  #returns a cached instance of the campaign
  def crafts_campaign
    return @campaign if defined?(@campaign) && !@campaign.nil?
    craft_campaign = self.campaign
  end

  def repo_status
    return @repo_status if defined?(@repo_status) && !@repo_status.nil?
    @repo_status = crafts_campaign.repo.status
  end

  #return true if the craft is not yet in the repo
  def is_new?
    return false if deleted?
    repo_status.untracked.keys.include?("Ships/#{craft_type.upcase}/#{name}.craft")
    #self.campaign.repo.status["Ships/#{craft_type.upcase}/#{name}.craft"].untracked == true
  end
  alias new_craft? is_new?

  #return true if the craft is in the repo and has changes.  If not in repo it returns nil.
  def is_changed? 
    return nil if is_new? 
    return false if deleted?
    repo_status.changed.keys.include?("Ships/#{craft_type.upcase}/#{name}.craft")
    #self.campaign.repo.status["Ships/#{craft_type.upcase}/#{name}.craft"].type == "M"
  end
  alias changed_craft? is_changed?

  
  def update_history_count
    self.update_attributes(:history_count => self.history.size)   
  end

  #return the commits for the craft (most recent first)
  def history
    return [] if is_new? || deleted?
    begin
      max_history_size = 100000
      logs = crafts_campaign.repo.log(max_history_size).object(file_name)
      logs.to_a
    rescue
      []
    end
  end


  #identify possible problems with adding craft to repo.
  def problems
    problems = []
    problems << "must not contain ` in name" if self.name.include?("`")
    problems
  end


  #takes a block to run and while the block is being run the persistence_checksum on the craft campaign is set to 'skip'
  #this means that the campaign will not be processed by the background monitor while the blocks actions are being carried out.
  def dont_process_campaign_while &blk
    self.campaign.update_attributes(:persistence_checksum => "skip") #unless self.campaign.persistence_checksum.eql?("skip")
    yield
    self.campaign.update_persistence_checksum
  end


  #stage the changes and commits the craft. simply returns if there are no changes.
  def commit args = {}
    #dont_process_campaign_while do 
      return "unable to commit; #{problems.join(",")}" unless problems.empty?

      @repo_status = nil #ensure fresh instance of repo, not cached
      repo = self.crafts_campaign.repo

      action = :deleted if self.deleted?
      action ||= self.is_new? ? :added : (self.is_changed? ? :updated : :nothing_to_commit)     
      
      unless action.eql?(:nothing_to_commit)
        message = "#{action} #{name}"
        message = args[:m] if args[:m]      
        if action.eql?(:deleted)
          repo.remove(self.file_name)
          self.history_count += 1
        else
          repo.add(self.file_name)
        end
        message << " #{self.commit_message}" unless self.commit_message.blank? || self.commit_message.eql?(message)
        self.commit_message = message
        repo.commit(message)
        self.last_commit = repo.log.first.to_s
      end

      unless action.eql?(:deleted)    
        self.part_count ||= 1
        self.part_count += 1 #temp till part count is implemented
        self.history_count = self.history.size
        self.history_count = 1 if self.history_count.eql?(0)        
      end
      self.save 
      @repo_status = nil    

      return action
    #end
  end



  #revert the craft to a previous commit
  def revert_to commit, options = {:commit => true}
    dont_process_campaign_while do 
      repo = self.campaign.repo
      index = history.reverse.map{|c| c.to_s}.index(commit.to_s) + 1
      repo.checkout_file(commit, file_name)
      self.update_attributes(:commit_message => commit.message)
      if options[:commit]
        begin
          repo.commit("reverted #{name} to V#{index}")
        rescue
        end
        update_history_count
      end
    end
  end

  def recover
    repo = self.campaign.repo
    commit = repo.gcommit(self.last_commit).parent
    repo.checkout_file(commit, self.file_name)
    repo.commit("recovered #{name}")
    self.deleted = false
    self.history_count = self.history.size
    self.last_commit = repo.log.first.to_s
    self.commit_message = commit.message
    self.save
  end 

  #git branch temp refb
  #git filter-branch -f --msg-filter "sed 's/test/testy/'" refa..temp
  #git rebase temp
  #git branch --delete temp
  def change_commit_message commit, new_message
    dont_process_campaign_while do 
      repo = self.campaign.repo
      temp_branch_name = "temp_message_change_branch"

      #create a new branch with it head as the commit I want to change (refb)
      repo.checkout(commit)
      repo.branch(temp_branch_name).checkout
      #and switch back to master
      repo.checkout("master")

      #This part uses system commands to interact with the git repo as 
      #I couldn't find a way using the git-gem to do filter-branch actions
      repo.with_working(campaign.path) do
        #used filter-branch with -msg-filter to replace text on all commits from the targets parent to the branch's head (which is just the desired commit)
        `git filter-branch -f --msg-filter \"sed 's/#{commit.message}/#{new_message}/'\" #{commit.parent}..#{temp_branch_name}`
        #rebase the temp branch back into master
        `git rebase #{temp_branch_name}`
      end

      #clean up - delete the temp branch
      repo.branch(temp_branch_name).delete
    end
  end

  def commit_message
    message = super
    return nil if self.is_changed? && message.eql?(self.history.first.message)
    message
  end

end
