class Task < ActiveRecord::Base
  attr_accessible :action, :failed


  def action
    begin
      JSON.parse(super)
    rescue
      super
    end
  end

  def action= args
    unless args.is_a?(String)
      args = args.to_json
    end
    super(args)
  end

  def process
    begin
      print "\nProcessing Delayed Task: "
      self.send(*self.action)
      self.destroy
      puts "\n"
    rescue
      self.update_attributes(:failed => true)
      puts "\n\nTask Failed to process. Could not perform #{self.action}\n\n"
    end
  end

  private
  
  def update_part_data_for instance_id
    instance = Instance.find(instance_id)
    print "updating part data on craft in #{instance.path}"
    instance.craft.where(:deleted => false).each{|c| 
      print "\n\tupdating #{c.name}"
      c.update_part_data
      c.save
    }
    instance.update_attributes(:part_update_required => false)
  end

  def update_some_craft_data
    to_update = Craft.where(:part_data => nil, :deleted => false).limit(40)
    return if to_update.blank?
    print "updating part data on #{to_update.count} un-processed craft"
    to_update.each{|c|
      print "\n\tupdating #{c.name}"
      c.update_part_data
      c.save
    }
  end

  def generate_part_db_for instance_id
    instance = Instance.find(instance_id)
    print "generating parts DB for #{instance.path}"
    instance.parts
  end

  def run_git_garbage_collector
    print "Compressing Git Repos (git gc)\n\n"
    sleep 1
    Campaign.all.each do |c|
      puts "#{c.name}..."
      c.repo.gc
    end 
  end

end
