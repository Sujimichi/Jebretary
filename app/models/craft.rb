class Craft < ActiveRecord::Base
  attr_accessible :name, :craft_type, :deleted
  belongs_to :campaign

  def self.identify_craft_in campaign
    dir = File.join(campaign.instance.path, "saves", campaign.name, "Ships")
    Dir.chdir(dir)
    {
      :vab => Dir.glob("VAB/*.craft").map{|craft| craft.gsub("VAB/", "")}, 
      :sph => Dir.glob("SPH/*.craft").map{|craft| craft.gsub("SPH/", "")}
    }
  end

  def self.verify_craft_for campaign
    files = Craft.identify_craft_in campaign
    existing_craft = Craft.where(:campaign_id => campaign.id)
    present_craft = {:sph => [], :vab => []}

    #create a new Craft object for each craft file found, unless a craft object for that craft already exists.
    files.each do |type, craft_files| 
      craft_files.each do |craft_name| 
        name = craft_name.sub(".craft","")
        if existing_craft.where(:name => name, :craft_type => type).empty?
          craft = Craft.new(:name =>  name, :craft_type => type)
          craft.campaign = campaign
          craft.save!
        end
        present_craft[type] << name
      end
    end

    #mark craft objects as deleted if the file no longer exists.
    existing_craft.each do |craft|
      next if present_craft[craft.craft_type.to_sym].include?(craft.name)
      craft.update_attributes(:deleted => true)
    end
  end

end
