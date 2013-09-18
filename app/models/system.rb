class System 

  def self.process

    System.set_db_flag({:status => :locked}) 
    #db_flag is a marker file placed on the HD to flag the DB as being locked. The server compnent will wait to perform DB actions while the db_flag file exists.  
    #The db_flag file is also used to pass information about long a running set of DB actions here to the server component (for example during the initial setup of a users craft.

    data = {} #the container for information to be passed to the front end. periodicaly updated and written to HD.
    instances = Instance.all

    #Console output
    unless instances.count.eql?(0)
      print "\nchecking craft files..." unless Rails.env.eql?("test")
      t = Time.now
    else
      print "\nWaiting for an instance of KSP to be defined" unless Rails.env.eql?("test")
    end

    instances.each{ |instance| data[instance.id] = {} } #put instance ids into data to be returned to interface. 
    #Done as separate step to enable faster return of info to interface
    craft_in_campaigns_for_instance = {} #container to hold mapping of craft files to campaigns in instances.

    #First main itteration throu instances - fast and provides some basic information to the user interface
    #determines which campaigns exist in each instance, creates new ones as appropriate
    #discovers the craft files associated with each campaign
    instances.each do |instance|
      campaign_names = instance.prepare_campaigns #checks the saves folder for campaign folders and creates campaigns where needed, returns array of campaign names

      #identify all craft files in VAB and SPH and return as hash of {campaign_name => {:sph => [], :vab => []}} for each campaign
      craft_in_campaigns = campaign_names.map{|name| {name => instance.identify_craft_in(name)} }.inject{|i,j| i.merge(j)}
      craft_in_campaigns_for_instance[instance.id] = craft_in_campaigns #store this mapping of craft files in campaigns against the instance id.

      campaigns = Campaign.where(:instance_id => instance.id).select{|c| c.exists?} #get all the campaign objects for those campaigns present in the save folder
      campaigns.each{|campaign| campaign.set_flag if campaign.should_process?}  #set the flag image on campaigns which 'should_process'

      #generate info for interface feedback.  How many total craft each campaign has (based on the files on the SPH and VAB folders)
      existing_camps = campaigns.map{|c| {c.name => { :id => c.id}} }.inject{|i,j| i.merge(j)}
      craft_in_campaigns.each{ |name, craft| existing_camps[name][:total_craft] = [craft[:vab], craft[:sph]].flatten.size }
      data[instance.id] = {:campaigns => existing_camps}
      System.update_db_flag(data) #update the DB flag file.
  
    end

    
    #Second main ittereation throu instances - variable, typically skips so is fast, but periodically runs for 10-15 times longer when actions are required.
    #Checks that each campaign that 'should_process' (ie has persistent.sfs change) has all the craft objects that it needs 
    #and that changes to those craft objects are tracked.  It also checks that deleted craft files have the relevent craft object deleted and ensure that 
    #objects that once existed in the repos history have a DB object to represent them (for recovery).
    instances.each do |instance|
      campaigns = Campaign.where(:instance_id => instance.id)   
      craft_in_campaigns = craft_in_campaigns_for_instance[instance.id] #get the craft files for the campaigns for this instance (generated in first itteration over instances)

      campaigns.each do |campaign|
        next unless campaign.exists?
        campaign.cache_instance(instance) #put the already loaded instance object into a variable in the campaign object to be used rather than reloading from DB.
        campaign.git #ensure git repo is present

        #check that all .craft files have a Craft object, or set Craft objects deleted=>true if file no longer exists
        data[instance.id][:campaigns][campaign.name][:creating_craft_objects] = true #put marker to say that we're now in the DB object creation step
        System.update_db_flag(data)        
        campaign.verify_craft craft_in_campaigns[campaign.name] #ensure all present craft files have a matching craft object
        data[instance.id][:campaigns][campaign.name][:creating_craft_objects] = false #remote the markers
        System.update_db_flag(data)

        next unless campaign.should_process?

        new_and_changed = campaign.new_and_changed
        craft = Craft.where(:campaign_id => campaign.id, :deleted => false)
     
        #craft which need to be commited - anything that is new, changed or does not have a history_count
        to_commit = [ 
          #craft.select{|c| c.history_count.nil?}, #did use "craft.where(:history_count => nil).to_a" but in tests this was selecting a craft with a history_count of 1
          craft.where(:history_count => nil).to_a,
          new_and_changed[:new].map{|file_name| craft.to_a.select{|c| c.file_name == file_name}},
          new_and_changed[:changed].map{|file_name| craft.to_a.select{|c| c.file_name == file_name}}
        ].flatten.compact.uniq

        #craft with outstanding message updates (used to be; [ ].flatten)        
        to_update = craft.where("commit_message is not null").to_a

        #pass in already loaded campaign object into craft object.
        [to_commit, to_update].flatten.each{|craft_object| craft_object.crafts_campaign = campaign }
          
        to_commit.each do |craft_object|         
          craft_object.commit #commit any craft that is_new? or is_changed? (in the repo sense, ie different from new? and changed?)
          data[instance.id][:campaigns][campaign.name][:added] = Craft.where("history_count is not null and campaign_id = #{campaign.id}").count
          System.update_db_flag(data) #inform interface of how many craft have been commited.
        end

        #update any craft that are holding commit message info in the temparary store.
        to_update.each{|craft_object| craft_object.update_repo_message_if_applicable }

        #update the checksum for the persistent.sfs file, indicating this campaign can be skipped until the file changes again.
        campaign.update_persistence_checksum 

      end
    end

    puts "done - (#{(Time.now - t).round(2)}seconds)" unless instances.count.eql?(0) || Rails.env.eql?("test")
    System.remove_db_flag
  end

  def self.set_db_flag content
    cur_dir = Dir.getwd
    Dir.chdir(System.root_path)
    File.open("#{Rails.env}_db_access", 'wb') {|f| f.write(content.to_json) }
    Dir.chdir(cur_dir)
  end

  def self.remove_db_flag
    begin
      cur_dir = Dir.getwd
      Dir.chdir(System.root_path)
      File.delete("#{Rails.env}_db_access")
      Dir.chdir(cur_dir)
    rescue
    end
  end

  def self.update_db_flag content 
    cur_dir = Dir.getwd
    Dir.chdir(System.root_path)
    File.open("#{Rails.env}_db_access", 'wb') {|f| f.write(content.to_json) }
    Dir.chdir(cur_dir)
  end

  def self.run_monitor
    s = System.new
    s.run_monitor
  end

  #return the path to folder where app or .exe is contained.
  def self.root_path
    if ENV["OCRA_EXECUTABLE"]
      if (RUBY_PLATFORM =~ /mswin|mingw|cygwin/)
        d = ENV["OCRA_EXECUTABLE"].split("\\")
      else
        d = ENV["OCRA_EXECUTABLE"].split("/")
      end
        return File.expand_path(File.join(d[0..d.size-2]))
    else
      return File.expand_path(File.join([Rails.root, ".."]))
    end
  end

  
  def self.run_monitor
    s = System.new
    s.run_monitor
  end

  def run_monitor
    @heart_rate = 10
    while @heart_rate do
      begin
        System.process
      rescue Exception => e 
        System.remove_db_flag
        puts "!!Monitor Error!! - Please Restart me!"
        puts e.message unless Rails.env.eql?("production")
      end
      sleep @heart_rate 
    end
  end

  def self.reset
    System.set_db_flag({:status => :locked})
    #Instance.destroy_all
    Campaign.destroy_all
    Craft.destroy_all
    System.remove_db_flag
  end

  def self.config
    path = File.join([System.root_path, "settings"])

  end
  
  def default_config
    config = {
      :seen_elements => []
    }
  end

  def get_config 
    set_config unless File.exists?( File.join([System.root_path, "settings"]) )
    config_data = File.open(File.join([System.root_path, "settings"]), 'r'){|f| f.readlines}.join
    JSON.parse(config_data)
  end

  def set_config new_config = nil
    new_config ||= default_config
    @config = nil
    File.open(File.join([System.root_path, "settings"]),'w'){|f| f.write(new_config.to_json)}
  end

  def config
    return @config if defined?(@config) && !@config.nil?
    @config = get_config
  end

  def config_get param
    config[param.to_s]
  end

  def config_set param, value
    config[param.to_s] = value
    set_config @config
  end

  def show_help_for? element
    #return true if Rails.env.eql?("development")
    seen_elements = config_get :seen_elements
    unless seen_elements.include?(element)
      seen_elements << element
      config_set :seen_elements, seen_elements
      return true
    end
    return false
  end


end

