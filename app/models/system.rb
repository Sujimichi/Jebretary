class System 

  def self.process
    Instance.all.each do |instance|
      campaign_names = instance.prepare_campaigns

      craft_in_campaigns = campaign_names.map{|name|
        {name => instance.identify_craft_in(name)}
      }.inject{|i,j| i.merge(j)}
      
      Campaign.where(:instance_id => instance.id).each do |campaign|
        campaign.git #ensure git repo is present
        #check that all .craft files have a Craft object, or set Craft objects deleted=>true if file no longer exists
        campaign.verify_craft craft_in_campaigns[campaign.name]
        
        if campaign.should_process?
          craft = Craft.where(:campaign_id => campaign.id)
          craft.each do |craft_object|
            craft_object.crafts_campaign = campaign #pass in already loaded campaign into craft
            next unless craft_object.is_new? || craft_object.is_changed? || craft_object.history_count.nil? 
            craft_object.commit
          end       
        end
        campaign.update_persistence_checksum
      end
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
      rescue    
        puts "DATABASE WAS LOCKED - twiddling thumbs"
      end
      sleep @heart_rate 
    end
  end

  def self.reset
    Instance.destroy_all
    Campaign.destroy_all
    Craft.destroy_all
  end

end

