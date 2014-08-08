class Campaign < ActiveRecord::Base
  include CommitMessageChanger
  include CommonLogic

  attr_accessible :instance_id, :name, :persistence_checksum, :sort_options
  
  belongs_to :instance
  has_many :craft, :dependent => :destroy
  has_many :subassemblies, :dependent => :destroy

  validates :name, :instance_id, :presence => true
  validates :commit_messages, :git_compatible => true


  def cache_instance given_instance
    return unless given_instance.id.eql?(self.instance_id)
    self.instance_variable_set :@instance, given_instance
  end
  def campaigns_instance= given_instance
    cache_instance given_instance
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

  #find the path to the flag used in this campaign from the persistent file
  def path_to_flag
    return nil unless File.exists?(File.join([self.path, "persistent.sfs"]))
    p_file = File.open(File.join([self.path, "persistent.sfs"]),'r'){|f| f.readlines}
    flag_line = p_file.select{|line| line.match /\sflag/}.first
    unless flag_line.blank?
      path = File.join([self.campaigns_instance.path,"GameData", flag_line.split(' = ').last.chomp]) << '.png'
      return path
    end
    return nil
  end

  #put a copy of the flag in the public dir so it can be used, named according to campaign id.
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
    Repo.open(self.path)
  end
  alias repo git
  
  #initialise the git repo and add a .gitignore to ignore the AutoSaved craft
  def create_repo
    return Repo.open(self.path) if Dir.entries(self.path).include?('.git')
    g = Repo.init(self.path)
    Dir.chdir(self.path)
    File.open('.gitignore', 'w'){|f| f.write("*~\n*.swp") }
    g.add('.gitignore')
    g.commit("Initial Commit")
    g
  end

  #notes the current dir, switches to given dir to run block and then returns to current dir.
  def within_dir dir, &blk
    cur_dir = Dir.getwd
    Dir.chdir(dir)
    yield
    Dir.chdir(cur_dir)
  end

  #add or update either the quicksave.sfs or persistent.sfs file to the repo.
  def track_save save_type = :quicksave, args = {}
    files = save_type.eql?(:both) ? ['persistent.sfs', 'quicksave.sfs'] : [(save_type.eql?(:persistent) ? 'persistent' : 'quicksave') << '.sfs']
    r = self.repo

    within_dir(self.path) do 
      files.each do |file|
        changed_file = r.changed.include?(file)
        if File.exists?(file) && (changed_file || r.untracked.include?(file))
          message = "added #{file}" 
          message = "updated #{file}" if changed_file
          message = args[:message] unless args[:message].blank?     
          puts message unless Rails.env.eql?("test")
          r.add(file)
          r.commit(message)
        end
      end
    end
  end

  #return true or false depending state of given save ie;
  #changed_save?(:quicksave) => true if the quicksave.sfs has changes.
  def changed_save? save_type, r = self.repo
    save_type = save_type.to_s << '.sfs' unless save_type.include?(".sfs")
    r.changed.include?(save_type)
  end

  #return the commits for the craft (most recent first)
  def save_history args = {:limit => false} 
    commits = {} 
    saves = [:quicksave, :persistent]
    saves.each do |save_type|
      begin
        save_commits = repo.log("#{save_type}.sfs", :limit => args[:limit])
        commits[save_type] = save_commits unless save_commits.empty?
      rescue
        commits[save_type] = []
      end  
    end
    commits
  end

  def revert_save save_type, commit, options = {}
    dont_process_while do 
      hist = save_history[save_type.to_sym]
      index = hist.reverse.map{|c| c.to_s}.index(commit.to_s) + 1
      self.repo.checkout_file(commit, "#{save_type}.sfs")
      if options[:commit]
        begin
          m = "reverted #{save_type} to V#{index}"
          repo.commit(m)
        rescue
        end
      end
    end
  end

  #overwrite the quicksave with the persistent file.
  def persistent_to_quicksave
    p_file = File.open(File.join([self.path, 'persistent.sfs']), 'r'){|f| f.readlines}
    File.open(File.join([self.path, 'quicksave.sfs']), 'w'){|f| f.write(p_file.join)}
  end


  #takes a block to run and while the block is being run the persistence_checksum is set to 'skip'
  #this means that the campaign will not be processed by the background monitor while the blocks actions are being carried out.
  def dont_process_while &blk
    self.update_attributes(:persistence_checksum => "skip") 
    yield
    self.update_persistence_checksum
  end

  #returns either :current_project, or :quicksave depending on which was most recently edited/commited.
  #if the quicksave was commited most recently then return  :quicksave 
  #if the current project was commited after a quicksave -> :current_project
  #if the current project was edited but not commited    -> :current_project
  #if the quicksave was commited most recently, but the current project remains edited but no commits -> :current_project
  def latest_commit current_project = last_changed_craft, saves = save_history, new_and_changed = new_and_changed    
    crft = "Ships/#{current_project.craft_type.upcase}/#{current_project.name}.craft" if current_project
       
    return :current_project if saves[:quicksave].nil? || saves[:quicksave].size.eql?(1)
    if new_and_changed[:changed].include?(crft) || new_and_changed[:new].include?(crft)
      return :current_project
    else  
      qs_commit = saves[:quicksave].first if saves[:quicksave]     
      if qs_commit && current_project
        craft_commit = current_project.history(:limit => 1).first
        t= [[:quicksave, qs_commit], [:current_project, craft_commit]].sort_by{|_, c| c.try(:date) || Time.now}.last
        return t[0]
      else
        return :current_project
      end
    end
  end
  

  #return hash containing :new and :changed keys, each entailing an array of craft file paths
  #for craft that are either untracked or which have changes.
  def new_and_changed 
    r = repo
    {
      :new     => r.untracked.select{|k| k.include?("Ships") && k.include?(".craft")},
      :changed => r.changed.select{  |k| k.include?("Ships") && k.include?(".craft")}
    }
  end

  #return true if objects (.craft or .sfs) that are tracked by the repo have changes.
  def has_untracked_changes? 
    not [repo.changed, repo.untracked].flatten.select do |k| 
      k.include?(".craft") || k.eql?("persistent.sfs") || k.eql?("quicksave.sfs") 
    end.empty?
  end
  def nothing_to_commit?
    not has_untracked_changes?
  end

  #return the craft which was most recently modified
  def last_changed_craft nac = new_and_changed #call new_and_changed just once, with option to pass it in if its already been called.
    last_updated = self.craft.where("deleted = ? and name != ?", false, "Auto-Saved Ship").order("updated_at").last

    if !nac[:changed].empty? || !nac[:new].empty?
      craft_names = nac[:changed].select{|c| !c.include?("Auto-Saved Ship")}
      craft_names = nac[:new].select{|c| !c.include?("Auto-Saved Ship")} unless nac[:new].empty?
      unless craft_names.empty?
        matched_craft = Craft.where(:name => craft_names.map{|cn| cn.split("/").last.sub(".craft","")}, :deleted => false, :campaign_id => self.id)
        matched_craft = matched_craft.sort_by{|c| File.mtime(c.file_path) if File.exists?(c.file_path) } 
        last_updated = matched_craft.last unless matched_craft.empty?
      end
    end
    last_updated
  end

  def update_persistence_checksum
    Dir.chdir(self.path)
    checksum = nil
    checksum = Digest::SHA256.file("persistent.sfs").hexdigest if File.exists?("persistent.sfs")
    self.update_attributes(:persistence_checksum => checksum)
  end


  #returns true or false.  should_process is used by System.process to determine if this campaign should be skipped or not.
  #returns true if there are different numbers of craft files to craft.where(:deleted => false) OR if the persistent.sfs checksum no longer matches.
  def should_process? 
    #return false if it has been set to skip processing    
    return false if self.persistence_checksum.eql?("skip")

    #return true if there are different number of craft files than records of craft that are not marked as deleted
    craft_files = campaigns_instance.identify_craft_in(self.name)
    craft = self.craft.where(:deleted => false) #if craft.nil?
    return true if craft_files.map{|k,v| v}.flatten.size != craft.count

    #return true if the stored checksum for persistent.sfs does not match the one generated for the current persistent.sfs
    Dir.chdir(self.path)
    return true unless File.exists?("persistent.sfs")
    checksum = Digest::SHA256.file("persistent.sfs").hexdigest
    not checksum.eql?(self.persistence_checksum)
  end


  #Check the database record of craft files against the actual files found in the campaign
  #If there are .craft files present that don't have a DB entry then create entires
  #If there are .craft files which have been deleted then set the corresponding DB record to deleted=true
  #Discover if there where any files which where deleted and commited in the repo and for which no DB entry exists
  #and create a DB entry which has deleted=true.  This is a slow step but only needs to be called once when the campaign is created.
  def verify_craft files = nil, args = {:discover_deleted => false}
    files = self.instance.identify_craft_in(self.name) if files.nil?

    present_craft = {:sph => [], :vab => []}    
    existing_craft = Craft.where(:campaign_id => self.id).to_a

    #this rats nest of chained loops is not really that horrible!
    #it takes the array of craft from the above select and groups them by craft_type. Then for each group it makes an hash of {craft_name => craft}. 
    #So it results in a hash of; craft_type => hash of {craft_name => craft}
    existing_craft_map = existing_craft.group_by{|c| c.craft_type}.map{|k,v| {k => v.map{|cc| {cc.name => cc}}.inject{|i,j|i.merge(j)} } }.inject{|i,j|i.merge(j)}

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
    
    #Discover deleted - any craft for which no file exists, but which at one point was in the repo
    if args[:discover_deleted]      
      ddc = [] #track to ensure each deleted craft is only processed once (in cases where a craft has been deleted multiple times)
      self.discover_deleted_craft(existing_craft_map).each do |del_inf|
        del_inf[:deleted].each do |craft_data|
          next if ddc.include? [craft_data[:craft_type], craft_data[:name]] #skip if a craft of this craft_type and name has already been processed
          ddc << [craft_data[:craft_type], craft_data[:name]] #otherwise add entry to store 
          #and create a craft object for the deleted craft.
          self.craft.create!(:name => craft_data[:name].sub(".craft",""), :craft_type => craft_data[:craft_type].downcase, :deleted => true, :last_commit => del_inf[:sha])
        end
      end
    end

    #remove craft from the repo if the file no longer exists and mark the craft as deleted
    existing_craft.select{|c| !c.deleted?}.each do |craft|
      next if present_craft[craft.craft_type.to_sym] && present_craft[craft.craft_type.to_sym].include?(craft.name)
      craft.deleted = true #actions in .commit will save this attribute
      craft.commit
    end
  end



  #find craft in the git repo which have already been deleted - in the case of Jebretary being setup on an existing git repo
  #Craft which hae been previously deleted will still get a Craft object assigned to enable recovery of them.
  #This uses command line git interface as the git-gem could not do --diff-filter commands (at least I couldn't find how to do it).
  #TODO tidy this nasty method up and make it run faster.
  def discover_deleted_craft existing_craft_map = nil
    #In the root of the campaigns git repo run the --diff-filter command and then return to the current working dir.
    log = self.repo.log_filterD
    

    #Select the craft already present in the DB which can either be from passed in existing_craft_map or directly from the DB
    if existing_craft_map
      existing_craft = {
        "VAB" => existing_craft_map.has_key?("vab") ? existing_craft_map["vab"].keys : [],
        "SPH" => existing_craft_map.has_key?("sph") ? existing_craft_map["sph"].keys : []
      }      
    else  
      existing_craft = {
        "VAB" => self.craft.where(:craft_type => "vab").map{|c| c.name},
        "SPH" => self.craft.where(:craft_type => "sph").map{|c| c.name}
      } 
    end

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


  def verify_subassemblies    
    #find the files present in subassemblies
    files = Dir.glob(File.join([self.path, "Subassemblies", "*.craft"])).map{|craft| craft.sub("#{self.path}/Subassemblies/", "").sub(".craft","") }

    #get names of existing subassemblies
    existing_subs = self.subassemblies.where(:deleted => false)
    existing_sub_names = existing_subs.map{|sub| sub.name}
    
    #itentify which ones are new and create subassembly instances for them
    #identify deleted subs that have returned and unmark them as deleted
    new_subs = files.select{|file| !existing_sub_names.include?(file) }       
    new_subs.each{|sub| 
      print "commiting new subassembly #{sub}..." unless Rails.env.eql?("test")
      deleted_sub = Subassembly.where(:campaign_id => self.id, :name => sub, :deleted => true).first
      if deleted_sub
        updated_sub = deleted_sub.update_attributes(:deleted => false) 
      else
        updated_sub = Subassembly.create(:campaign_id => self.id, :name => sub) 
        updated_sub.commit(:repo => self.repo)
      end
      puts "done" unless Rails.env.eql?("test")
    }
        
    #identify subs that have been deleted and mark them deleted
    campaign_path = self.path
    existing_subs.each{|sub|
      unless File.exists?(sub.path(campaign_path)) && !sub.deleted?
        sub.update_attributes(:deleted => true) 
        sub.commit(:repo => self.repo)
      end
    }
  end

  def track_changed_subassemblies
    changed_sub_names = repo.changed.select{|i| i.include?("Subassemblies")}.map{|sub| sub.split("/").last}.map{|name| name.gsub(".craft","")}
    changed_subs = changed_sub_names.map{|sub| Subassembly.where(:campaign_id => self.id, :name => sub).first}.compact
    changed_subs.each{|sub| 
      print "commiting subassembly #{sub.name}..." unless Rails.env.eql?("test")
      sub.commit
      puts "done" unless Rails.env.eql?("test")
    }
  end

end
