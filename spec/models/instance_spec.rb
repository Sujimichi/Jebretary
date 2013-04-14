require 'spec_helper'

def in_test_dir &blk
  d = Dir.getwd
  Dir.chdir "#{Rails.root}/temp_test_dir"
  yield
  Dir.chdir d
end

describe Instance do
  before(:all) do 
    FileUtils.rm_rf "temp_test_dir"
    Dir.mkdir "temp_test_dir"
    Dir.chdir "temp_test_dir"
  end
  #pending "add some examples to (or delete) #{__FILE__}"

  describe "discover_campaigns" do 
    before(:each) do 
      in_test_dir do 
        FileUtils.rm_rf "KSP_test"
        Dir.mkdir "KSP_test"
        Dir.chdir "KSP_test"
        Dir.mkdir "saves"
        Dir.chdir "saves"
      end
      Dir.chdir("#{Rails.root}/temp_test_dir/KSP_test")
      p = Dir.getwd.split("/").to_json
      @i = Instance.new(:full_path => p)
      Dir.chdir Rails.root
      
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

#  Dir.chdir("KSP_test/saves")

  end
end
