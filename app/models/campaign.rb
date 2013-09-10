class Campaign < ActiveRecord::Base
  require 'git'

  attr_accessible :instance_id, :name, :persistence_checksum
  
  belongs_to :instance
  has_many :craft, :dependent => :destroy

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

  def exists?
    File.exists? self.path
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
      img = File.open(path, 'rb'){|f| f.readlines}.join
      File.open(File.join([Rails.root, 'public', "flag_for_campaign_#{self.id}.png"]), 'wb'){|f| f.write(img)}
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

  def last_changed_craft nac = new_and_changed #call new_and_changed just once
    last_updated = self.craft.where("deleted = ? and name != ?", false, "Auto-Saved Ship").order("updated_at").last
    
    unless nac[:changed].empty? && nac[:new].empty?
      craft_name = nac[:changed].select{|c| !c.include?("Auto-Saved Ship")}.first
      craft_name = nac[:new].select{|c| !c.include?("Auto-Saved Ship")}.first unless nac[:new].empty?
      if craft_name
        matched_craft = self.craft.where(:name => craft_name.split("/").last.sub(".craft",""), :deleted => false)
        last_updated = matched_craft.first unless matched_craft.empty?
      end
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

    existing_craft = Craft.where(:campaign_id => self.id)
    present_craft = {:sph => [], :vab => []}

    #create a new Craft object for each craft file found, unless a craft object for that craft already exists.
    files.each do |type, craft_files| 
      craft_files.each do |craft_name| 
        name = craft_name.sub(".craft","")
        matches = existing_craft.where(:name => name, :craft_type => type)
        if matches.empty?
          craft = self.craft.create(:name =>  name, :craft_type => type)
          self.persistence_checksum = nil
        else
          match = matches.first
          match.recover if match.deleted?
        end
        present_craft[type] << name
      end
    end
    self.save

    ddc = []
    self.discover_deleted_craft.each do |del_inf|
      del_inf[:deleted].each do |craft_data|
        next if ddc.include? [craft_data[:craft_type], craft_data[:name]]

        ddc << [craft_data[:craft_type], craft_data[:name]]
        puts [craft_data[:name], self.name]
        self.craft.create!(
          :name => craft_data[:name].sub(".craft",""), 
          :craft_type => craft_data[:craft_type].downcase, 
          :deleted => true,
          :last_commit => del_inf[:sha]
        )
      end
    end


    #remove craft from the repo if the file no longer exists and mark the craft as deleted
    existing_craft.where(:deleted => false).each do |craft|
      next if present_craft[craft.craft_type.to_sym] && present_craft[craft.craft_type.to_sym].include?(craft.name)
      craft.deleted = true #actions in .commit will save this attribute
      craft.commit
    end
  end



  def discover_deleted_craft

    cur_dir = Dir.getwd
    Dir.chdir(self.path)  
    log = `git log --diff-filter=D --summary`
    Dir.chdir(cur_dir)
    
    existing_craft = {
      "VAB" => self.craft.where(:craft_type => "vab").map{|c| c.name},
      "SPH" => self.craft.where(:craft_type => "sph").map{|c| c.name}
    }
    logs = self.repo.log.map{|log| log.to_s}

    log = log.split("commit ")
        
    log = log.map{|l|
      l.split("\n")
    }.select{|l| !l.empty?}.map{|l|
      next unless logs.include?(l[0])
      commit_info = {
        :sha => l[0],
        :deleted => l.select{|line| line.include?("delete mode")}.map{|line| line.gsub("delete mode 100644","").strip}.map{|data|
          s = data.sub("Ships/","").split("/")
          d = {:craft_type => s[0], :name => s[1]}
          d = nil if !["SPH","VAB"].include?(d[:craft_type]) || existing_craft[d[:craft_type]].include?(d[:name].sub(".craft",""))
          d
        }.compact
      }
      commit_info = nil if commit_info[:deleted].compact.empty?
      commit_info
    }.compact

    log
  end



end
