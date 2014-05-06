class Subassembly < ActiveRecord::Base
  attr_accessible :campaign_id, :history_count, :name, :deleted

  belongs_to :campaign


  def path campaign_path = nil
    campaign_path ||= self.campaign.path
    File.join([campaign_path,"Subassemblies", self.name << ".craft"])
  end
end
