class System

  def self.monitor
    Instance.all.each do |instance|
      instance.prepare_campaigns
      instance.reload

      campaigns = instance.campaigns.includes(:craft)
      campaigns.each do |campaign|
        campaign.git #ensure git repo is present
        Craft.verify_craft_for campaign #check that all .craft files have a Craft object, or set Craft objects deleted=>true if file no longer exists
        campaign.reload
        campaign.craft.select{|craft| 
          craft.crafts_campaign = campaign #pass in already loaded campaign into craft
          craft.is_new? || craft.is_changed? 
        }.each do |craft|
          craft.commit
        end        
      end
    end
  end

  def run_monitor
    @heart_rate = 10
    while @heart_rate do
      System.monitor
      sleep @heart_rate 
    end
  end

  #RAILS_ENV=production script/delayed_job --queue=tracking start
  def self.start_monitor
    s = System.new
    s.delay(:queue => "monitor").run_monitor
    #Delayed::Job.enqueue(System.run_monitor, :queue => "monitor")
  end


  def self.reset
    Instance.destroy_all
    Campaign.destroy_all
    Craft.destroy_all
  end

end
