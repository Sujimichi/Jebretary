require 'spec_helper'

describe Subassembly do
  
  describe 'path' do 
    before(:each) do 
      @campaign = set_up_sample_data
      make_sample_subassemblies 
    end
  
    it 'should return its full path' do 
      sub = Subassembly.create(:name => "subass1", :campaign_id => @campaign.id)
      sub.path.should == File.join([Rails.root, "/temp_test_dir/KSP_test/saves/test_campaign", "Subassemblies", "subass1.craft"])      
    end
  end

  describe "commit" do 
    before(:each) do 
      @campaign = set_up_sample_data
      make_sample_subassemblies 
    end

    it 'should add the subassembly to its campaigns repo' do 
      sub = Subassembly.create(:name => "subass1", :campaign_id => @campaign.id)
      @campaign.repo.tracked.should_not be_include "Subassemblies/subass1.craft"
      sub.commit
      @campaign.repo.tracked.should be_include "Subassemblies/subass1.craft"

      @campaign.repo.log.first.message.should == "added subassembly: subass1"
    end

    it 'should update a changed subassembly' do 
      sub = Subassembly.create(:name => "subass1", :campaign_id => @campaign.id)
      sub.commit
      @campaign.repo.changed.should be_empty
      
      File.open(sub.path, 'w'){|f| f.write "something different"}
      @campaign.repo.changed.should_not be_empty
      
      sub.commit
      @campaign.repo.changed.should be_empty
      @campaign.repo.log.first.message.should == "updated subassembly: subass1"     
    end

  end

  describe "history" do 
    before(:each) do 
      @campaign = set_up_sample_data
      make_sample_subassemblies 
    end

    it 'should return the commits for the subassembly' do 
      sub = Subassembly.create(:name => "subass1", :campaign_id => @campaign.id)
      sub.history.should be_empty

      sub.commit
      sub.history.size.should == 1
        
    end
  end

end
