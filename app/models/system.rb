class System 

  def self.process

    System.set_db_flag({:status => :locked})
    data = {}

    instances = Instance.all
    instances.each{ |instance| data[instance.id] = {} }
    craft_in_campaigns_for_instance = {}


    instances.each do |instance|
      campaign_names = instance.prepare_campaigns

      craft_in_campaigns = campaign_names.map{|name|
        {name => instance.identify_craft_in(name)}
      }.inject{|i,j| i.merge(j)}
      craft_in_campaigns_for_instance[instance.id] = craft_in_campaigns

      campaigns = Campaign.where(:instance_id => instance.id)
      existing_camps = campaigns.map{|c| {c.name => { :id => c.id}} }.inject{|i,j| i.merge(j)}

      craft_in_campaigns.each{ |name, craft| existing_camps[name][:total_craft] = [craft[:vab], craft[:sph]].flatten.size }

      data[instance.id] = {:campaigns => existing_camps}
      System.update_db_flag(data)
  
    end

    instances.each do |instance|
      campaigns = Campaign.where(:instance_id => instance.id)   
      craft_in_campaigns = craft_in_campaigns_for_instance[instance.id]

      campaigns.each do |campaign|
        campaign.git #ensure git repo is present
        #check that all .craft files have a Craft object, or set Craft objects deleted=>true if file no longer exists

        data[instance.id][:campaigns][campaign.name][:creating_craft_objects] = true
        System.update_db_flag(data)
        campaign.verify_craft craft_in_campaigns[campaign.name]
        data[instance.id][:campaigns][campaign.name][:creating_craft_objects] = false
        System.update_db_flag(data)

        next unless campaign.should_process?
        craft = Craft.where(:campaign_id => campaign.id)
        craft.each do |craft_object|
          craft_object.crafts_campaign = campaign #pass in already loaded campaign into craft
          next unless craft_object.is_new? || craft_object.is_changed? || craft_object.history_count.nil? 
          craft_object.commit
          data[instance.id][:campaigns][campaign.name][:added] = Craft.where("history_count is not null and campaign_id = #{campaign.id}").count
          System.update_db_flag(data)

        end       
        campaign.update_persistence_checksum
      end
    end
    System.remove_db_flag
  end

  def self.set_db_flag content
    cur_dir = Dir.getwd
    Dir.chdir(File.join([Rails.root, ".."]))
    File.open("#{Rails.env}_db_access", 'w') {|f| f.write(content.to_json) }
    Dir.chdir(cur_dir)
  end

  def self.remove_db_flag
    begin
      cur_dir = Dir.getwd
      Dir.chdir(File.join([Rails.root, ".."]))
      File.delete("#{Rails.env}_db_access")
      Dir.chdir(cur_dir)
    rescue
    end
  end

  def self.update_db_flag content 
    cur_dir = Dir.getwd
    Dir.chdir(File.join([Rails.root, ".."]))
    File.open("#{Rails.env}_db_access", 'w') {|f| f.write(content.to_json) }
    Dir.chdir(cur_dir)
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
      rescue    
        puts "DATABASE WAS LOCKED - twiddling thumbs"
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

end

