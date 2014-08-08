class Instance < ActiveRecord::Base
  attr_accessible :full_path, :part_db_checksum, :part_update_required

  validates :full_path, :presence => true
  has_many :campaigns, :dependent => :destroy
  has_many :craft, :through => :campaigns

  def path
    p = JSON.parse(self.full_path)
    File.join(p)
  end

  def name
    File.split(self.path).last
  end
    
  def exists?
    File.exists? self.path
  end

  def discover_campaigns
    ignored = ['.', '..', 'training', 'scenarios']
    save_dir = File.join(self.path, "saves")
    dirs = Dir.entries(save_dir).select{|entry| 
      File.directory? File.join(save_dir,entry) and !ignored.include?(entry)
    }
  end

  def prepare_campaigns
    existing_campaigns = discover_campaigns
    new_campaigns = []
    known_campaign_names = self.campaigns.map{|c| c.name}
    existing_campaigns.each do |camp|
      next if known_campaign_names.include?(camp)
      new_campaigns << Campaign.create!(:name => camp, :instance_id => self.id)
    end
    [existing_campaigns, new_campaigns]
  end

  #return the .craft files found in VAB and SPH
  def identify_craft_in campaign_name
    dir = File.join(self.path, "saves", campaign_name, "Ships")
    Dir.chdir(dir)
    {
      :vab => Dir.glob("VAB/*.craft").map{|craft| craft.gsub("VAB/", "")}, 
      :sph => Dir.glob("SPH/*.craft").map{|craft| craft.gsub("SPH/", "")}
    }
  end

  #return the parts info for this instance.  Either from an already loaded instance of @parts, or loaded from the .partsDB file (if present)
  #or if neither @parts or the .partsDB file are present a fresh parts map is made (and saved to the .partsDB file).
  #Each time System is startd up (ie each time Jebretary is launched) the partsDB file is reset and rebuilt (this is done by System)
  def parts
    if defined?(@parts) && !@parts.nil?
      return @parts 
    else
      if File.exists?(File.join([self.path, "jebretary.partsDB"]))
        return @parts = PartParser.new(self.path, :source => :from_file)
      else
        @parts = PartParser.new(self.path, :source => :game_folder, :write_to_file => true)

        #we need to know if there has been a change in the installed parts since the last time Jebretary was launched.
        #therefore a checksum of the partsDB is stored and if it differs from the current checksum then part_update_required is set to true
        #this will be used to prompt the user about re-processing all craft in this instance for thier parts.
        pdc = generate_part_db_checksum
        if self.part_db_checksum != pdc
          self.part_update_required = true unless self.part_db_checksum.nil?
          self.part_db_checksum = pdc          
          self.save
        end
        return @parts
      end
    end  
  end

  def generate_part_db_checksum
    path = File.join([self.path, "jebretary.partsDB"])    
    File.exists?(path) ? Digest::SHA256.file(path).hexdigest : nil
  end

  def reset_parts_db
    path = File.join([self.path, "jebretary.partsDB"])
    File.delete(path) if File.exists?(path)
  end


end

