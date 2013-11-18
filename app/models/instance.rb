class Instance < ActiveRecord::Base
  attr_accessible :full_path

  validates :full_path, :presence => true
  has_many :campaigns, :dependent => :destroy

  def path
    p = JSON.parse(self.full_path)
    File.join(p)
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



end

