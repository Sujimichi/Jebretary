class Craft < ActiveRecord::Base
  attr_accessible :name, :craft_type, :deleted, :part_count, :history_count
  belongs_to :campaign

  require 'active_support/builder'

  #return the .craft files found in VAB and SPH
  def self.identify_craft_in campaign
    dir = File.join(campaign.instance.path, "saves", campaign.name, "Ships")
    Dir.chdir(dir)
    {
      :vab => Dir.glob("VAB/*.craft").map{|craft| craft.gsub("VAB/", "")}, 
      :sph => Dir.glob("SPH/*.craft").map{|craft| craft.gsub("SPH/", "")}
    }
  end


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
      next if present_craft[craft.craft_type.to_sym].include?(craft.name)
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

  #stage the changes and commits the craft. simply returns if there are no changes.
  def commit args = {}
    return "unable to commit; #{problems.join(",")}" unless problems.empty?
    @repo_status = nil
    action = self.is_new? ? :added : (self.is_changed? ? :updated : :nothing_to_commit)
    unless action.eql?(:nothing_to_commit)
      message = "#{action} #{name}"
      message = args[:m] if args[:m]
      repo = self.crafts_campaign.repo
      repo.add("Ships/#{craft_type.upcase}/#{name}.craft")
      self.part_count ||= 1
      self.part_count += 1
      self.save #temp till part count is implemented
      repo.commit(message)
    end
    @repo_status = nil    
    update_history_count
    return action
  end

  def update_history_count
    self.update_attributes(:history_count => self.history.size)   
  end

  #identify possible problems with adding craft to repo.
  def problems
    problems = []
    problems << "must not contain ` in name" if self.name.include?("`")
    problems
  end

  #return the commits for the craft (most recent first)
  def history
    return [] if is_new?
    max_history_size = 100000
    logs = crafts_campaign.repo.log(max_history_size).object(file_name)
    logs.to_a
  end

  #revert the craft to a previous commit
  def revert_to commit
    repo = self.campaign.repo
    repo.checkout_file(commit, file_name)
    begin
      repo.commit("reverted #{name}")
    rescue
    end
  end

  def change_commit_message commit, new_message
=begin
git branch temp refb

git filter-branch --env-filter '
export GIT_AUTHOR_EMAIL="foo@example.com"' refa..temp

git rebase temp
git branch --delete temp
=end
  
    repo = self.campaign.repo
    temp_branch_name = "temp_message_change_branch"

    #create a new branch from the commit I want to change (refb)
    repo.checkout(commit)
    repo.branch(temp_branch_name).checkout
    repo.checkout("master")

  
    repo.with_working(campaign.path) do
      #git filter-branch -f --msg-filter "sed 's/test/testy/'" refa..temp
      command = "git filter-branch -f --msg-filter \"sed 's/#{commit.message}/#{new_message}/'\" #{commit.parent}..#{temp_branch_name}"
      `#{command}`
      `git rebase #{temp_branch_name}`
    end

    repo.branch(temp_branch_name).delete

  end

end
