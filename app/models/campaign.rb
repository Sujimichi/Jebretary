class Campaign < ActiveRecord::Base
  require 'git'

  attr_accessible :instance_id, :name, :persistence_checksum
  
  belongs_to :instance
  has_many :craft

  validates :name, :instance_id, :presence => true


  def cache_instance instance
    return unless instance.id.eql?(self.instance_id)
    campaigns_instance = instance
  end
  def campaigns_instance= instance
    @instance = instance
  end
  def campaigns_instance
    return @instance if defined?(@instance) && !@instance.nil?
    campaigns_instance = self.instance
  end
  
  def path
    File.join(campaigns_instance.path, "saves", self.name)
  end

  def path_to_flag
    p_file = File.open(File.join([self.path, "persistent.sfs"]),'r'){|f| f.readlines}
    flag_line = p_file.select{|line| line.match /\sflag/}.first
    unless flag_line.blank?
      path = File.join([self.instance.path,"GameData", flag_line.split(' = ').last.chomp]) << '.png'
      return path
    end
    return nil
  end

  def set_flag
    path = path_to_flag
    return nil unless path
    begin
      img = File.open(path, 'r'){|f| f.readlines}.join
      File.open(File.join([Rails.root, 'public', "flag_for_campaign_#{self.id}.png"]), 'w'){|f| f.write(img)}
      "/flag_for_campaign_#{self.id}.png"
    rescue
      nil
    end
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
    last_updated = self.craft.where(:deleted => false).order("updated_at").last
    new = new_and_changed[:new]
    unless new_and_changed[:changed].empty? 
      craft_name = new_and_changed[:changed].first
      craft_name = new.first unless new.empty?

      matched_craft = self.craft.where(:name => craft_name.split("/").last.sub(".craft",""), :deleted => false)
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
    #return false if it has been set to skip processing
    return false if self.persistence_checksum.eql?("skip")

    #return true if there are different number of craft files than records of craft that are not marked as deleted
    craft_files = campaigns_instance.identify_craft_in(self.name)
    return true if craft_files.map{|k,v| v}.flatten.size != self.craft.where(:deleted => false).count

    #return true if the stored checksum for persistent.sfs does not match the one generated for the current persistent.sfs
    Dir.chdir(self.path)
    checksum = Digest::SHA256.file("persistent.sfs").hexdigest
    not checksum.eql?(self.persistence_checksum)
  end

  #create Craft objects for each .craft found and mark existing Craft objects as deleted is the .craft no longer exists.
  def verify_craft files = nil
    files = self.instance.identify_craft_in(self.name) if files.nil?

    existing_craft = Craft.where(:campaign_id => self.id, :deleted => false)
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
      next if craft.deleted?
      craft.remove_from_repo
      craft.commit
      craft.update_attributes(:deleted => true)
    end
  end



end
