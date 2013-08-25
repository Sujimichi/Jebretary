class Campaign < ActiveRecord::Base
  require 'git'

  attr_accessible :instance_id, :name, :persistence_checksum
  
  belongs_to :instance
  has_many :craft

  validates :name, :instance_id, :presence => true


  def path
    File.join(self.instance.path, "saves", self.name)
  end

  def git
    return create_repo unless Dir.entries(self.path).include?('.git') #create the repo if it is not present.
    Git.open(self.path)
  end
  alias repo git

  #initialise the git repo and add a .gitignore to ignore the AutoSaved craft
  def create_repo
    return Git.open(self.path) if Dir.entries(self.path).include?('.git')
    g = Git.init(self.path)
    Dir.chdir(self.path)
    File.open('.gitignore', 'w'){|f| f.write("") }
    g.add('.gitignore')
    g.commit("Initial Commit")
    g
  end


  def new_and_changed
    status = repo.status
    {
      :new => status.untracked.keys,
      :changed => status.changed.keys
    }
  end

  def last_changed_craft
    last_updated = self.craft.order("updated_at").last
    new = new_and_changed[:new] - ["persistent.sfs", "quicksave.sfs"]
    unless new_and_changed[:changed].empty? 
      craft_name = new_and_changed[:changed].first
      craft_name = new.first unless new.empty?

      matched_craft = self.craft.where(:name => craft_name.split("/").last.sub(".craft",""))
      last_updated = matched_craft.first unless matched_craft.empty?
    end
    last_updated
  end

  def update_persistence_checksum
    Dir.chdir(self.path)
    checksum = Digest::SHA256.file("persistent.sfs").hexdigest
    self.update_attributes(:persistence_checksum => checksum)
  end

  def should_process?
    return false if self.persistence_checksum.eql?("skip")
    Dir.chdir(self.path)
    checksum = Digest::SHA256.file("persistent.sfs").hexdigest
    not checksum.eql?(self.persistence_checksum)
  end

end
