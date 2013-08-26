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
      :new => status.untracked.keys.select{|k| k.include?("Ships") && k.include?(".craft")},
      :changed => status.changed.keys.select{|k| k.include?("Ships") && k.include?(".craft")}
    }
  end

  def last_changed_craft
    last_updated = self.craft.order("updated_at").last
    new = new_and_changed[:new]
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

  #create Craft objects for each .craft found and mark existing Craft objects as deleted is the .craft no longer exists.
  def verify_craft files = nil
    files = self.instance.identify_craft_in(self.name) if files.nil?

    existing_craft = Craft.where(:campaign_id => self.id)
    present_craft = {:sph => [], :vab => []}

    #create a new Craft object for each craft file found, unless a craft object for that craft already exists.
    files.each do |type, craft_files| 
      craft_files.each do |craft_name| 
        name = craft_name.sub(".craft","")
        if existing_craft.where(:name => name, :craft_type => type).empty?
          craft = Craft.new(:name =>  name, :craft_type => type)
          craft.campaign = self
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



end
