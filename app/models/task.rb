class Task < ActiveRecord::Base
  attr_accessible :action, :failed


  def action
    begin
      JSON.parse(super)
    rescue
      super
    end
  end

  def process
    #begin
      #eval(action) #yeah I know, horrible to use eval like this, but a) this is just while I rough out what I need this to do b) task actions will only ever be set by the system, never the user. But still eval is nasty, will do something else later.
      print "\nProcessing Delayed Task: "
      self.send(*self.action)
      self.destroy
      puts "done"
    #rescue
    #  self.update_attributes(:failed => true)
    #end
  end

  #Instance.find(id).craft.each{|c| c.update_part_data; c.save}

  
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
end
