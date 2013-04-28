class Craft < ActiveRecord::Base
  attr_accessible :name, :craft_type, :deleted
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

  #return true if the craft is not yet in the repo
  def is_new?
    #self.campaign.repo.status.untracked.keys.include?("Ships/#{craft_type.upcase}/#{name}.craft")
    self.campaign.repo.status["Ships/#{craft_type.upcase}/#{name}.craft"].untracked == true
  end
  alias new_craft? is_new?

  #return true if the craft is in the repo and has changes.  If not in repo it returns nil.
  def is_changed?
    return nil if is_new?
    #self.campaign.repo.status.changed.keys.include?("Ships/#{craft_type.upcase}/#{name}.craft")
    self.campaign.repo.status["Ships/#{craft_type.upcase}/#{name}.craft"].type == "M"
  end
  alias changed_craft? is_changed?

  #stage the changes and commits the craft. simply returns if there are no changes.
  def commit
    action = self.is_new? ? :added : (self.is_changed? ? :updated : :nothing_to_commit)
    unless action.eql?(:nothing_to_commit)
      message = "#{action} #{name}"
      repo = self.campaign.repo
      repo.add("Ships/#{craft_type.upcase}/#{name}.craft")
      repo.commit(message)
    end
    return action
  end

  #return the commits for the craft (most recent first)
  def history
    logs = self.campaign.repo.log.object(file_name)
    logs.to_a
  end

  #revert the craft to a previous commit
  def revert_to commit
    repo = self.campaign.repo
    repo.checkout_file(commit, file_name)
    repo.commit("reverted #{name}")
  end

end
