require 'spec_helper'

describe Instance do
  before(:all) do 
    set_test_dir
  end
  
  it 'should have a full_path' do 
    @i = FactoryGirl.create(:instance)
    @i.full_path.should == ["", "home", "sujimichi", "Share", "jebretary", "temp_test_dir", "KSP_test"].to_json
  end

  it 'should return the OS path' do 
    @i = FactoryGirl.create(:instance)
    @i.path.should == "/home/sujimichi/Share/jebretary/temp_test_dir/KSP_test"
  end

  describe "discover_campaigns" do 
    before(:each) do 
      in_test_dir do 
        set_basic_mock_KSP_dir
      end
      @i = FactoryGirl.create(:instance)
    end

    it 'should return empty array with none present' do 
      @i.discover_campaigns.should == []
    end
    it 'should return array with existing campaigns' do 
      in_test_dir do 
        Dir.chdir "KSP_test/saves"
        Dir.mkdir "camp1"
      end
      @i.discover_campaigns.should == ["camp1"]
      in_test_dir do 
        Dir.chdir "KSP_test/saves"
        Dir.mkdir "camp2"
      end
      @i.discover_campaigns.should == ["camp1", "camp2"]
    end

    it "should not return 'training or scenarios'" do 
      in_test_dir do 
        Dir.chdir "KSP_test/saves"
        Dir.mkdir "camp1"
        Dir.mkdir "training"
        Dir.mkdir "scenarios"
      end
      @i.discover_campaigns.should == ["camp1"]
    end
  end

  describe "prepare_campaigns" do 
    before(:each) do 
      in_test_dir do 
        FileUtils.rm_rf "KSP_test"
        Dir.mkdir "KSP_test"
        Dir.chdir "KSP_test"
        Dir.mkdir "saves"
        Dir.chdir "saves"
        Dir.mkdir "camp1"
        Dir.mkdir "camp2"
      end
      #@i = Instance.create!(FactoryGirl.attributes_for(:instance))
      @i = FactoryGirl.create(:instance)
      Dir.chdir Rails.root      
    end

    it 'should create a Campaign for each discovered campaign if the campaign is not already created' do 
      Campaign.should_receive(:create!).once.with(:name => "camp1", :instance_id => @i.id).ordered
      Campaign.should_receive(:create!).once.with(:name => "camp2", :instance_id => @i.id).ordered
      @i.campaigns.should be_empty
      @i.prepare_campaigns
    end


    it 'should not create Campaigns for those already discovered' do 
      @i.save!
      Campaign.create!(:name => "camp1", :instance_id => @i.id)
      Campaign.should_receive(:create!).once.with(:name => "camp2", :instance_id => @i.id).ordered
      Campaign.should_not_receive(:create!).with(:name => "camp1", :instance_id => @i.id).ordered
      @i.prepare_campaigns
    end

  end


  describe "identify_craft_in" do 
    before(:each) do 
      @campaign = set_up_sample_data
    end

    it 'should identify all present craft files in VAB and SPH' do 
      files = @instance.identify_craft_in(@campaign.name)
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
      files = @instance.identify_craft_in(@campaign.name)
      files[:vab].should_not contain("not_a_craft.file")
    end

  end
end
