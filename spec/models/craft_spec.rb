require 'spec_helper'

describe Craft do
  
  describe "identify_craft" do 
    before(:each) do 
      @campaign = set_up_sample_data
    end

    it 'should identify all present craft files in VAB and SPH' do 
      files = Craft.identify_craft_in(@campaign)
      files.should be_a(Hash)
      files.should have_key(:vab)
      files.should have_key(:sph)
      files[:vab].should be_a(Array)
      files[:sph].should be_a(Array)
      
      files[:vab].should contain("my_rocket.craft")
      files[:vab].should contain("my_other_rocket.craft")
      files[:sph].should contain("my_rocket_car.craft")


    end



  end
  
end
