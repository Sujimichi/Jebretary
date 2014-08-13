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

    it 'should commit a deleted subassembly' do 
      sub = Subassembly.create(:name => "subass1", :campaign_id => @campaign.id)
      sub.commit
      @campaign.repo.changed.should be_empty

      File.delete(sub.path)
      sub.deleted = true

      sub.commit

      @campaign.repo.changed.should be_empty
      @campaign.repo.log.first.message.should == "deleted subassembly: #{sub.name}"
            
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


  describe "move_to" do 
    before(:each) do 
      make_campaign_dir "test_campaign_1", :reset => true
      make_campaign_dir "test_campaign_2", :reset => false
      @instance = FactoryGirl.create(:instance)
      Dir.chdir File.join(@instance.path, "saves", "test_campaign_1")
      make_sample_data     
      Dir.chdir File.join(@instance.path, "saves", "test_campaign_2")
      make_sample_data
      System.process

      @campaign_1 = Campaign.where(:name => "test_campaign_1").first
      @campaign_2 = Campaign.where(:name => "test_campaign_2").first
      add_subassembly "subass1", :in => @campaign_1
      System.process
     
      @sub = @campaign_1.subassemblies.find_by_name("subass1")
      @sub.commit
    end
    
    it 'should move subassembly to the other campaign' do 
      @campaign_1.subassemblies.count.should == 1
      @campaign_2.subassemblies.count.should == 0

      Dir.entries(File.join([@campaign_1.path, "Subassemblies"])).should be_include("#{@sub.name}.craft")
      Dir.entries(File.join([@campaign_2.path])).should_not be_include("Subassemblies") #campaign_2 doesn't have any subs or dir for them yet

      @sub.move_to @campaign_2

      @campaign_1.subassemblies.count.should == 0
      @campaign_2.subassemblies.count.should == 1

      Dir.entries(File.join([@campaign_1.path, "Subassemblies"])).should_not be_include("#{@sub.name}.craft")
      Dir.entries(File.join([@campaign_2.path, "Subassemblies"])).should be_include("#{@sub.name}.craft")
      @sub.campaign.should == @campaign_2

    end

    it 'should not move the subassembly if one is already present' do 
      File.open(@sub.file_path,'w'){|f| f.write("something particular written in this craft")}
      add_subassembly "subass1", :in => @campaign_2
      @sub2 = @campaign_2.subassemblies.create!(:name => "subass1")
      @sub2.commit

      @sub.move_to(@campaign_2).should be_false
      File.open(@sub2.file_path,'r'){|f| f.readline}.should == "some test data"
      @sub.campaign.should == @campaign_1
    end

    it 'should move the subassembly if one is already present if the replace option is given' do 
      File.open(@sub.file_path,'w'){|f| f.write("something particular written in this craft")}
      add_subassembly "subass1", :in => @campaign_2
      @sub2 = @campaign_2.subassemblies.create!(:name => "subass1")
      @sub2.commit

      @sub.move_to(@campaign_2, :replace => true).should be_true
      File.open(@campaign_2.subassemblies.first.file_path,'r'){|f| f.readline}.should == "something particular written in this craft"
      Subassembly.where(:name => "subass1").count.should == 2
      Subassembly.where(:name => "subass1").first.campaign.should == @campaign_1
      Subassembly.where(:name => "subass1").first.should be_deleted
      Subassembly.where(:name => "subass1").last.campaign.should == @campaign_2
    end

    it 'should leave the originals in place if given the copy option' do 
      @sub.campaign.should == @campaign_1      
      @campaign_1.subassemblies.map{|c| c.name}.should be_include(@sub.name)
      @campaign_2.subassemblies.map{|c| c.name}.should_not be_include(@sub.name)
      Dir.entries(File.join([@campaign_1.path, "Subassemblies"])).should be_include("#{@sub.name}.craft")
      Dir.entries(File.join([@campaign_2.path])).should_not be_include("Subassemblies") #campaign_2 doesn't have any subs or dir for them yet
      #Dir.entries(File.join([@campaign_2.path, "Subassemblies"])).should_not be_include("#{@sub.name}.craft")

      @sub.move_to @campaign_2, :copy => true

      Dir.entries(File.join([@campaign_1.path, "Subassemblies"])).should be_include("#{@sub.name}.craft")
      Dir.entries(File.join([@campaign_2.path, "Subassemblies"])).should be_include("#{@sub.name}.craft")
      @campaign_1.reload.subassemblies.map{|c| c.name}.should be_include(@sub.name)
      @campaign_2.reload.subassemblies.map{|c| c.name}.should be_include(@sub.name)
      @sub.campaign.should == @campaign_1
      Subassembly.where(:name => "subass1").count.should == 2
    end

  end

  describe "syncing craft between campaigns" do 
    before(:each) do 
      make_campaign_dir "test_campaign_1", :reset => true
      make_campaign_dir "test_campaign_2", :reset => false
      @instance = FactoryGirl.create(:instance)
      Dir.chdir File.join(@instance.path, "saves", "test_campaign_1")
      make_sample_data :with_craft => false, :with_subs => true
      Dir.chdir File.join(@instance.path, "saves", "test_campaign_2")
      make_sample_data :with_craft => false, :with_subs => false
      System.process

      @campaign_1 = Campaign.where(:name => "test_campaign_1").first
      @campaign_2 = Campaign.where(:name => "test_campaign_2").first
      
      add_subassembly "sync_this_sub", :in => @campaign_1

      @sub = @campaign_1.subassemblies.create!(:name => "sync_this_sub")
      @sub.commit
    end

       
    describe "sync_with" do 

      it "should add the given campaign to the crafts 'sync[:with]' list" do 
        @sub.sync.should == {:with => []}
        @sub.sync_with @campaign_2
        @sub.sync[:with].should == [@campaign_2.id]
      end

      it 'should append additional campaing_ids to the sync_list' do
        @sub.sync_with @campaign_2
        @sub.sync[:with].should == [@campaign_2.id]

        @sub.sync_with 42
        @sub.sync[:with].should == [@campaign_2.id, 42]        
      end
    end

    describe "synchronize" do
      before(:each) do 
        @sub.sync_with @campaign_2
      end
    
      it 'should create the sub in another campaign if it doesnt already exist' do 
        @campaign_2.subassemblies.should be_empty
        
        @sub.synchronize
        
        @campaign_2.reload
        @campaign_2.subassemblies.count.should == 1
        @campaign_2.subassemblies.first.name.should == "sync_this_sub"      
      end

      describe "with existing sub in target campaign" do 
        before(:each) do           
          add_subassembly "sync_this_sub", :in => @campaign_2
          @campaign_2.subassemblies.create!(:name => "sync_this_sub").commit
          @campaign_2.subassemblies.count.should == 1
          File.open(File.join([@campaign_2.path, "Subassemblies", "sync_this_sub.craft"]), "r"){|f| f.readlines}.join.should == "some test data"

          #change the data in the first craft 
          change_sub_contents @sub, "some different file data"
        end

        it 'should update the sub in another campaing if it already exists' do 
          @sub.commit
          @sub.synchronize
  
          @campaign_2.reload
          File.open(File.join([@campaign_2.path, "Subassemblies", "sync_this_sub.craft"]), "r"){|f| f.readlines}.join.should == "some different file data"    
        end

        it 'should keep the id of the sub in the target campaign' do 
          id = @campaign_2.subassemblies.first.id
          @sub.commit
          @sub.synchronize
  
          @campaign_2.reload
          @campaign_2.subassemblies.first.id.should == id
        end

        it 'should copy the commit message over to the target sub' do 
          @sub.commit :m => "this is a test commit"
          @sub.synchronize          
          @sub.reload.history.first.message.should == "this is a test commit"

          @campaign_2.reload
          @campaign_2.subassemblies.first.history.first.message.should == "this is a test commit"
        end

      end

      describe "syncing in both directions" do 
        before(:each) do 
          
          add_subassembly "sync_this_sub", :in => @campaign_2
          @sub2 = @campaign_2.subassemblies.create!(:name => "sync_this_sub")
          @sub2.commit

          #first sync from campaign_1 to campaing_2 (as in the above tests)
          change_sub_contents @sub, "change made in campaign_1"
          @sub.commit :m => "changed craft in camp1"
          @sub.synchronize          
          [@sub, @sub2].each{|c| c.reload}
        end

        it 'should sync from campaign_2 to campaign_1' do 
          change_sub_contents @sub2, "change made in campaign_2"
          @sub2.commit :m => "changed craft in camp2"
          @sub2.synchronize          

          File.open(@sub.path, "r"){|f| f.readlines}.join.should == "change made in campaign_2"
          @sub.history.first.message.should == "changed craft in camp2"
        end

      end

    end 
  end
end
