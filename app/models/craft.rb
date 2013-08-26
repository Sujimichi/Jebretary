class Craft < ActiveRecord::Base
  attr_accessible :name, :craft_type, :deleted, :part_count, :history_count
  belongs_to :campaign

  require 'active_support/builder'

  #create Craft objects for each .craft found and mark existing Craft objects as deleted is the .craft no longer exists.
  def self.verify_craft_for campaign
    files = Craft.identify_craft_in campaign
    existing_craft = Craft.where(:campaign_id => campaign.id)
    present_craft = {:sph => [], :vab => []}

    #create a new Craft object for each craft file found, unless a craft object for that craft already exists.
    files.each do |type, craft_files| 
      craft_files.each do |craft_name| 
        name = craft_name.sub(".craft","")
        if existing_craft.where(:name => name, :craft_type => type).empty?
          craft = Craft.new(:name =>  name, :craft_type => type)
          craft.campaign = campaign
          craft.save!
        end
        present_craft[type] << name
      end
    end

    #mark craft objects as deleted if the file no longer exists.
    existing_craft.each do |craft|
      next if present_craft[craft.craft_type.to_sym] && present_craft[craft.craft_type.to_sym].include?(craft.name)
      craft.update_attributes(:deleted => true)
    end
  end

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
    repo_status.untracked.keys.include?("Ships/#{craft_type.upcase}/#{name}.craft")
    #self.campaign.repo.status["Ships/#{craft_type.upcase}/#{name}.craft"].untracked == true
  end
  alias new_craft? is_new?

  #return true if the craft is in the repo and has changes.  If not in repo it returns nil.
  def is_changed? 
    return nil if is_new? 
    repo_status.changed.keys.include?("Ships/#{craft_type.upcase}/#{name}.craft")
    #self.campaign.repo.status["Ships/#{craft_type.upcase}/#{name}.craft"].type == "M"
  end
  alias changed_craft? is_changed?

  
  def update_history_count
    self.update_attributes(:history_count => self.history.size)   
  end

  #return the commits for the craft (most recent first)
  def history
    return [] if is_new?
    max_history_size = 100000
    logs = crafts_campaign.repo.log(max_history_size).object(file_name)
    logs.to_a
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
      @repo_status = nil
      action = self.is_new? ? :added : (self.is_changed? ? :updated : :nothing_to_commit)
      unless action.eql?(:nothing_to_commit)
        message = "#{action} #{name}"
        message = args[:m] if args[:m]
        repo = self.crafts_campaign.repo
        repo.add("Ships/#{craft_type.upcase}/#{name}.craft")
        repo.commit(message)
      end
      self.part_count ||= 1
      self.part_count += 1 #temp till part count is implemented
      self.history_count = self.history.size
      self.history_count = 1 if self.history_count.eql?(0)
      self.save 
      @repo_status = nil    

      return action
    #end
  end



  #revert the craft to a previous commit
  def revert_to commit
    dont_process_campaign_while do 
      repo = self.campaign.repo
      index = history.reverse.map{|c| c.to_s}.index(commit.to_s) + 1
      repo.checkout_file(commit, file_name)
      begin
        repo.commit("reverted #{name} to V#{index}")
      rescue
      end
      update_history_count    
    end
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

end
