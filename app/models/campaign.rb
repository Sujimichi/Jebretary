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
    File.open('.gitignore', 'w'){|f| f.write("*~\n*.swp") }
    g.add('.gitignore')
    g.commit("Initial Commit")
    g
  end

  def within_dir dir, &blk
    cur_dir = Dir.getwd
    Dir.chdir(dir)
    yield
    Dir.chdir(cur_dir)
  end

  #add or update either the quicksave.sfs or persistent.sfs file to the repo.
  def track_save save_type = :quicksave, args = {}
    if save_type.eql?(:both)
      files = ['persistent.sfs', 'quicksave.sfs']
    else
      files = [(save_type.eql?(:persistent) ? 'persistent' : 'quicksave') << '.sfs']
    end
    status = repo.status
    within_dir(self.path) do 
      files.each do |file|
        next unless File.exists?(file) #&& changed_save?(save_type)
        message = "updated #{file}"   
        message = "added #{file}" if status.untracked.keys.include?(file)
        message = args[:message] unless args[:message].blank?     
        repo.add(file)
        begin
          repo.commit(message)
        rescue
          #just carry on, this is incase there aren't any changes to the save, rather than call repo.status again (which has mem leak)
        end
      end
    end
  end

  #return true or false depending state of given save ie;
  #changed_save?(:quicksave) => true if the quicksave.sfs is either untracked or has changes.
  def changed_save? save_type
    save_type = save_type.to_s << '.sfs'
    status = self.repo.status
    status.untracked.keys.include?(save_type) || status.changed.keys.include?(save_type)
  end


  #return hash containing :new and :changed keys, each entailing an array of craft file paths
  #for craft that are either untracked or which have changes.
  def new_and_changed
    status = repo.status
    {
      :new => status.untracked.keys.select{|k| k.include?("Ships") && k.include?(".craft")},
      :changed => status.changed.keys.select{|k| k.include?("Ships") && k.include?(".craft")}
    }
  end

  def has_untracked_changes?
    status = self.repo.status
    not [status.untracked.keys, status.changed.keys].flatten.select do |k| 
      (k.include?("Ships") && k.include?(".craft")) || k.include?(".sfs") 
    end.empty?
  end
  def nothing_to_commit?
    not has_untracked_changes?
  end

  #return the craft which was most recently modified
  def last_changed_craft nac = new_and_changed #call new_and_changed just once
    last_updated = self.craft.where("deleted = ? and name != ?", false, "Auto-Saved Ship").order("updated_at").last

    if !nac[:changed].empty? || !nac[:new].empty?
      craft_names = nac[:changed].select{|c| !c.include?("Auto-Saved Ship")}
      craft_names = nac[:new].select{|c| !c.include?("Auto-Saved Ship")} unless nac[:new].empty?
      unless craft_names.empty?
        matched_craft = Craft.where(:name => craft_names.map{|cn| cn.split("/").last.sub(".craft","")}, :deleted => false, :campaign_id => self.id)
        matched_craft = matched_craft.sort_by{|c| File.mtime(c.file_path)} 
        last_updated = matched_craft.last unless matched_craft.empty?
      end
    end
    last_updated
  end


  def update_persistence_checksum
    Dir.chdir(self.path)
    checksum = Digest::SHA256.file("persistent.sfs").hexdigest
    self.update_attributes(:persistence_checksum => checksum)
  end


  #returns true or false.  should_process is used by System.process to determine if this campaign should be skipped or not.
  #returns true if there are different numbers of craft files to craft.where(:deleted => false) OR if the persistent.sfs checksum no longer matches.
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

    present_craft = {:sph => [], :vab => []}    
    existing_craft = Craft.where(:campaign_id => self.id)

    #this rats nest of nested loops is not really that horrible!
    #it takes the array of craft from the above select and groups them by craft_type. Then for each group it makes an hash of {craft_name => craft}. So it results in a hash
    #of craft_type => hash of {craft_name => craft}
    existing_craft_map = existing_craft.to_a.group_by{|c| c.craft_type}.map{|k,v| {k => v.map{|cc| {cc.name => cc}}.inject{|i,j|i.merge(j)} } }.inject{|i,j|i.merge(j)}

    
    #create a new Craft object for each craft file found, unless a craft object for that craft already exists.
    files.each do |type, craft_files| #files is grouped by craft_type
      craft_files.each do |craft_name| 
        name = craft_name.sub(".craft","") #get the name of the craft 
        #and determine if a craft by that name already exists in that craft_type.
        match = existing_craft_map[type.to_s][name] if existing_craft_map && !existing_craft_map[type.to_s].nil?
        if match.nil?
          craft = self.craft.create(:name =>  name, :craft_type => type) #if the match is nil, create a Craft object
          self.persistence_checksum = nil #set checksum to nil so next pass of System.process will process this campaign.
        elsif match.deleted?
          match.update_attributes(:deleted => false, :history_count => nil) #if the craft object was marked as deleted, but the file was restored, then un-mark the DB object.
          self.persistence_checksum = nil #set checksum to nil so next pass of System.process will process this campaign.
        end
        present_craft[type] << name #add name to list which is used later to indicate which crafts to NOT mark as deleted 
      end
    end
    self.save if self.changed?

    ddc = [] #track to ensure each deleted craft is only processed once (in cases where a craft has been deleted multiple times)
    self.discover_deleted_craft.each do |del_inf|
      del_inf[:deleted].each do |craft_data|
        next if ddc.include? [craft_data[:craft_type], craft_data[:name]] #skip if a craft of this craft_type and name has already been processed
        ddc << [craft_data[:craft_type], craft_data[:name]] #otherwise add entry to store 
        #and create a craft object for the deleted craft.
        self.craft.create!(:name => craft_data[:name].sub(".craft",""), :craft_type => craft_data[:craft_type].downcase, :deleted => true, :last_commit => del_inf[:sha])
      end
    end


    #remove craft from the repo if the file no longer exists and mark the craft as deleted
    existing_craft.where(:deleted => false).each do |craft|
      next if present_craft[craft.craft_type.to_sym] && present_craft[craft.craft_type.to_sym].include?(craft.name)
      craft.deleted = true #actions in .commit will save this attribute
      craft.commit
    end
  end



  #find craft in the git repo which have already been deleted - in the case of Jebretary being setup on an existing git repo
  #Craft which hae been previously deleted will still get a Craft object assigned to enable recovery of them.
  #This uses command line git interface as the git-gem could not do --diff-filter commands (at least I couldn't find how to do it).
  def discover_deleted_craft

    #In the root of the campaigns git repo run the --diff-filter command and then return to the current working dir.
    cur_dir = Dir.getwd
    Dir.chdir(self.path)  
    log = `git log --diff-filter=D --summary` #find the commits in which a file was deleted.
    Dir.chdir(cur_dir)
    
    #Select the craft already present in the DB
    existing_craft = {
      "VAB" => self.craft.where(:craft_type => "vab").map{|c| c.name},
      "SPH" => self.craft.where(:craft_type => "sph").map{|c| c.name}
    }

    #get all the SHA_ID's used in the campaigns repo
    logs = self.repo.log.map{|log| log.to_s}

    #split logs so that each element contains one commit and each commit is an array, the 1st element of which is the SHA_ID
    log = log.split("commit ").map{|l| l.split("\n") }.select{|l| !l.empty?}

    log.map{|l|
      next unless logs.include?(l[0]) #perhaps un-nessesary, a security step to ensure this only examines commits whos SHA_ID matches one in this repo.
      commit_info = {
        :sha => l[0], #first element is the SHA_ID
        #select lines which include "delete mode" and remove the "delete mode" text.  Each line (of which there maybe 1 or more) is a file which was deleted.
        :deleted => l.select{|line| line.include?("delete mode")}.map{|line| line.gsub("delete mode 100644","").strip}.map{|data|
          s = data.sub("Ships/","").split("/")      #assume the file path has 'Ships/' and remove it and split on '/'
          d = {:craft_type => s[0], :name => s[1]}  #assuming the file is a craft, the first element will be VAB or SPH and the 2nd element will be the name.craft
          d = nil unless d[:name].include?('.craft')#set d to nil 'skip' if the name does not include .craft
          #second skip clause, skip if the craft type is not either VAB or SPH and skip if the existing craft already contain a craft by that name (for that craft_type).
          d = nil if !["SPH","VAB"].include?(d[:craft_type]) || existing_craft[d[:craft_type]].include?(d[:name].sub(".craft",""))
          d
        }.compact #remove the nil'ed entries
      }
      commit_info = nil if commit_info[:deleted].compact.empty? #if all the entries were nil'ed then skip this commit
      commit_info
    }.compact #remove the nil'ed commits.
  end

end
