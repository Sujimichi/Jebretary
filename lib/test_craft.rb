class TestCraft
  attr_accessor :craft, :campaign, :file

  def initialize campaign_id, name = "test_craft", craft_type = :vab
    raise "am i still using this?"
    @campaign = Campaign.find(campaign_id)
    @file = File.join([@campaign.path, "Ships", craft_type.to_s.upcase, "#{name}.craft"])
    File.open(@file, 'w'){|f| f.write("A Craft")}
    System.process
    @craft = Craft.where(:name => name, :campaign_id => @campaign.id).first
  end

  def rand_edit
    data = File.open(@file, 'r'){|f| f.readlines}
    data << "fooblah#{rand}"
    File.open(@file, 'w'){|f| f.write data.join}
  end 

  def edit_p_file
    edit_file type = :persistent
  end
  def edit_s_file
    edit_file type = :quicksave
  end

  def edit_file type = :persistent
    save_file = (type.eql?(:persistent) ? 'persistent' : 'quicksave') << '.sfs'
    path = File.expand_path(File.join([@campaign.path, save_file]))
    file_data = File.open(path, 'r'){|f| f.readlines}
    e_line = file_data.select{|line| line.include?("CanQuickSave")}.first
    i = file_data.index(e_line)
    file_data[i] = file_data[i].sub("True", "True#{(10*rand).round}")
    File.open(path, 'w'){|f| f.write file_data.join}
  end

  def test
    threads= []

    rand_edit
    edit_p_file  

    threads << Thread.new{
      #sleep 1
      System.process
    }
    threads << Thread.new{
      controller_update_action :update_message => "this is a test message"
    }
    threads
  end

  def test2
    rand_edit
    edit_p_file
    System.process
  end

  def controller_update_action params
    @craft = @craft.reload
    @campaign = @campaign.reload
    commit = @craft.history.first
    if @campaign.reload.nothing_to_commit?
      @craft.commit_message = params[:update_message] #message may not be saved, but is set so that validations can be used to checks its ok to write to repo.
      if @craft.valid? #run validations
        @craft.change_commit_message(commit, params[:update_message]) #update the message to the repo
        if commit.eql?(@craft.history.first) #in the case where this is the current commit then 
          @craft.commit_message = nil #set the commit message to nil it has been written to the repo
        else
          @craft.reload #if not then reload the craft to restore the commit message to how it was before being used in the validation
        end         
      end
    else
      #if there are untracked changes in the repo the message is cached on the craft object, to be written to the repo later.
      @craft.commit_message = params[:update_message] if commit.to_s.eql?(@craft.history.first.to_s)
    end
    @craft.save if @craft.valid?
  end

  def process
    System.process
  end

  def commit
    @craft.commit
  end

end

puts "do this \n\t t = TestCraft.new(1, 'athingybob', :vab)"

