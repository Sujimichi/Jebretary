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

    it 'should not track non .craft files' do 
      Dir.chdir("Ships/VAB")
      File.open("not_a_craft.file", "w"){|f| f.write("some test data")}
      files = Craft.identify_craft_in(@campaign)
      files[:vab].should_not contain("not_a_craft.file")
    end


  end


  describe "verify_craft_for campaign" do 
    before(:each) do 
      @campaign = set_up_sample_data
    end

    it 'should create a Craft model for each craft identified' do 
      Craft.count.should == 0
      @campaign.craft.should be_empty
      Craft.verify_craft_for @campaign
      Craft.count.should == 3
      @campaign.reload
      @campaign.craft.size.should == 3
      @campaign.craft.select{|craft| craft.craft_type == "vab"}.size.should == 2
      @campaign.craft.select{|craft| craft.craft_type == "sph"}.size.should == 1
      @campaign.craft.map{|craft| craft.name}.sort.should == ['my_rocket', 'my_other_rocket', 'my_rocket_car'].sort
    end

    it 'should not create a new craft object if one for that name and type already exists' do 
      Craft.verify_craft_for @campaign
      @campaign.craft.size.should == 3
      Dir.chdir("SPH")
      File.open("my_other_rocket.craft",'w'){|f| f.write("slkjlksjfj")} #create a craft in SPH with same name as one in VAB
      Craft.verify_craft_for @campaign
      @campaign.craft.size.should == 4
    end

    it 'should mark existing craft objects as deleted if the .craft file is no longer present' do 
      Craft.verify_craft_for @campaign
      @campaign.craft.map{|craft| craft.deleted?}.all?.should be_false
      File.delete("VAB/my_other_rocket.craft")
      Craft.verify_craft_for @campaign
      @campaign.craft.map{|craft| craft.deleted? }.all?.should be_false
      @campaign.craft.where(:craft_type => 'vab', :name => "my_other_rocket").first.deleted.should be_true
    end



  end
  
end
