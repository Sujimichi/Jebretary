class System 

  def self.process

    System.set_db_flag({:status => :locked})
    data = {}

    instances = Instance.all

    unless instances.count.eql?(0)
      print "\nchecking craft files..." unless Rails.env.eql?("test")
      t = Time.now
    else
      print "\nWaiting for an instance of KSP to be defined" unless Rails.env.eql?("test")
    end

    instances.each{ |instance| data[instance.id] = {} }
    craft_in_campaigns_for_instance = {}

    instances.each do |instance|
      campaign_names = instance.prepare_campaigns

      craft_in_campaigns = campaign_names.map{|name|
        {name => instance.identify_craft_in(name)}
      }.inject{|i,j| i.merge(j)}
      craft_in_campaigns_for_instance[instance.id] = craft_in_campaigns

      campaigns = Campaign.where(:instance_id => instance.id).select{|c| c.exists?}
      campaigns.each{|campaign| campaign.set_flag if campaign.should_process?}
      existing_camps = campaigns.map{|c| {c.name => { :id => c.id}} }.inject{|i,j| i.merge(j)}

      craft_in_campaigns.each{ |name, craft| existing_camps[name][:total_craft] = [craft[:vab], craft[:sph]].flatten.size }

      data[instance.id] = {:campaigns => existing_camps}
      System.update_db_flag(data)
  
    end

    instances.each do |instance|
      campaigns = Campaign.where(:instance_id => instance.id)   
      craft_in_campaigns = craft_in_campaigns_for_instance[instance.id]

      campaigns.each do |campaign|
        next unless campaign.exists?
        campaign.cache_instance(instance)
        campaign.git #ensure git repo is present

        #check that all .craft files have a Craft object, or set Craft objects deleted=>true if file no longer exists
        data[instance.id][:campaigns][campaign.name][:creating_craft_objects] = true
        System.update_db_flag(data)
        campaign.verify_craft craft_in_campaigns[campaign.name]
        data[instance.id][:campaigns][campaign.name][:creating_craft_objects] = false
        System.update_db_flag(data)

        next unless campaign.should_process?
        craft = Craft.where(:campaign_id => campaign.id, :deleted => false)
        craft.each do |craft_object|
          craft_object.crafts_campaign = campaign #pass in already loaded campaign into craft          
          if craft_object.is_new? || craft_object.is_changed? || craft_object.history_count.nil? 
            craft_object.commit          
          else
            craft_object.update_repo_message_if_applicable
          end
          data[instance.id][:campaigns][campaign.name][:added] = Craft.where("history_count is not null and campaign_id = #{campaign.id}").count
          System.update_db_flag(data)

        end       
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

