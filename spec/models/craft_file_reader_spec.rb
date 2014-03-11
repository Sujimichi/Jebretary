require 'spec_helper'

describe CraftFileReader do

  before(:each) do 
    set_up_sample_data
    file = File.open(Rails.root.join("lib", "test.craft"), 'r'){|f| f.readlines}
    path = File.join([@campaign.path, "Ships", "VAB", "test.craft"])
    File.open(path, 'w'){|f| f.write file.join}

    @campaign.verify_craft
    @campaign.craft.each{|c| c.commit}
    @campaign.track_save :both

    @craft = @campaign.craft.where(:name => "test", :craft_type => "vab").first
    @path = File.join([@campaign.path, @craft.file_name])
  end

  it 'should identify parts' do 
    reader = CraftFileReader.new(@path)
    raise reader.parts.inspect
    

  end


end

