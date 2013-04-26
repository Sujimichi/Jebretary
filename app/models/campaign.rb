class Campaign < ActiveRecord::Base
  require 'git'
  attr_accessible :instance_id, :name
  belongs_to :instance
  has_many :craft

  validates :name, :instance_id, :presence => true

  #initialise the git repo and add a .gitignore to ignore the AutoSaved craft
  def create_repo
    return Git.open(self.path) if Dir.entries(self.path).include?('.git')
    g = Git.init(self.path)
    File.open('.gitignore', 'w'){|f| f.write("Auto-Saved*") }
    g.add('.gitignore')
    g.commit("Initial Commit")
    g
  end

  def git
    return create_repo unless Dir.entries(self.path).include?('.git') #create the repo if it is not present.
    Git.open(self.path)
  end

  def path 
    File.join(self.instance.path, "saves", self.name)
  end

  def commit_craft
    g = self.git
    g.add("Ships/SPH/*.craft")
    g.add("Ships/VAB/*.craft")
    updated = g.status.changed.map{|name, craft| g.add(name); name}
    added = g.status.added.keys
    message = ""
    message << "Added craft: #{added.map{|ship| ship.sub('Ships/', '')}.join(", ") }" unless added.empty?
    message << "Updated craft: #{updated.map{|ship| ship.sub('Ships/', '')}.join(", ") }" unless updated.empty?
    g.commit(message)
  end

  def commit_saves
    g = self.git
    saves = %w[quicksave.sfs persistent.sfs]   
    saves.each{|save| g.add(save)}
    message = "Added quicksave and persistent save files" if g.status.added.keys.include?("persistent.sfs") and g.status.added.keys.include?("quicksave.sfs")
    if g.status.changed.keys.include?("persistent.sfs") && g.status.changed.keys.include?("quicksave.sfs")
      message = "Updated quicksave and persistent save files" 
    else
      message = "Updated quicksave file" if g.status.changed.keys.include?("quicksave.sfs") &! g.status.changed.keys.include?("persistent.sfs")
      message = "Updated persistent file" if g.status.changed.keys.include?("persistent.sfs") &! g.status.changed.keys.include?("quicksave.sfs")
    end
    message ||= "added .sfs files" 
    g.commit(message)
  end

  


  #scan craft folders and identify craft files 
  #   - all craft files should have a coresponding Craft object, it can be deleted but would get replaced if the craft still exists.
  #   - it should continue to exist once the craft is deleted to enable referencing it in the git repo.
  #create craft object for each one
  #pass craft objects to commit_craft (with option for craft objects to be excluded from commit)
  #commit (update or add) craft defined by given craft objects
  #
end
