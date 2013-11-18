class CraftsController < ApplicationController

  respond_to :html, :js

  def index
    if params.include?(:campaign_id)
      campaign = Campaign.find(params[:campaign_id])
      @craft = campaign.craft
    else 
      @craft = Craft.all
    end
    respond_with(@craft) do |f|      
      f.js { }
      f.html { }
    end    

  end

  def show
    
    respond_with(@craft) do |f|
      f.html{
        @craft = Craft.find(params[:id])
      }
      f.js{
        ensure_no_db_lock do         
          @craft = Craft.find(params[:id])
          @history = @craft.history
        end
      }
    end
  end

  def edit
    @craft = Craft.find(params[:id])
    @sha_id = params[:sha_id]
    history = @craft.history     
    @commit = history.select{|commit| commit.sha == @sha_id}.first
    @is_changed = @craft.is_changed?

    if params[:message_form] 
      @commit = "most_recent" if @commit.nil?
      @commit_messages = @craft.commit_messages
    end

    unless @craft.deleted? || params[:message_form]      
      @revert_to_version = history.reverse.index(@commit) + 1
      @current_version = @craft.history_count
    end
    @return_to = params[:return_to]
    respond_with(@craft) do |f|
      f.html{}
      f.js {
        
      }
    end
  end

  def update
    @craft = Craft.find(params[:id])
    @campaign = @craft.campaign
    history = @craft.history

    commit = @campaign.repo.gcommit(params[:sha_id])

    @craft.revert_to commit, :commit => params[:commit_revert].eql?("true") if params[:revert_craft]
    @craft.recover if @craft.deleted? && params[:recover_deleted]

    if params[:force_commit]
      @craft.commit :m => @craft.commit_messages["most_recent"]
      msgs = @craft.commit_messages
      msgs.delete("most_recent")
      @craft.commit_messages = msgs
      @craft.save
    end
    

    #change sha_id from "most_recent" if the craft no longer has untracked changes.
    #this is to catch the situation where the user started writting a commit message on a craft with untracked changes 
    #and while they where writting the craft got automatically tracked.  
    commit = @craft.history.first unless @craft.is_changed? if params[:sha_id].eql?("most_recent") 

    #updating commit message - prob also move this to spearate controller
    if params[:update_message]
      params[:update_message].gsub!("\n","<br>") #replace new line tags with line break tags (\n won't commit to repo)
      unless history.first.message == params[:update_message]
        messages = @craft.commit_messages
        messages[commit] = params[:update_message]
        @craft.commit_messages = messages
        @craft.save! if @craft.valid? 
        @errors = {:update_message => @craft.errors.full_messages.join} unless @craft.errors.empty?      
      end
    end

    respond_with(@craft) do |f|
      f.html{
        if params[:return_to] && params[:return_to] == "campaign"
          redirect_to @campaign
        else
          redirect_to @craft
        end
      }
      f.js {}
    end

  end

  def destroy
    @craft = Craft.find(params[:id])
    @craft.delete_craft
    redirect_to @craft.campaign
  end
end
