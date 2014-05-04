class Subassembly < ActiveRecord::Base
  attr_accessible :campaign_id, :history_count, :name

  belongs_to :campaign


  def path
    File.join([self.campaign.path,"Subassemblies", self.name << ".craft"])
  end
end
