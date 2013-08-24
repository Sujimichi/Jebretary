class Instance < ActiveRecord::Base
  attr_accessible :full_path

  validates :full_path, :presence => true

  has_many :campaigns

  def path
    p = JSON.parse(self.full_path)
    File.join(p)
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
    known_campaign_names = self.campaigns.map{|c| c.name}
    existing_campaigns.each do |camp|
      next if known_campaign_names.include?(camp)
      Campaign.create!(:name => camp, :instance_id => self.id)
    end
  end

end

