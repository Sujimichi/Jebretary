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

    if params[:message_form] && @commit.nil?
      @commit = "most_recent"
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
    @craft.commit if params[:force_commit]


    #TODO move this to separate controller 
    if params[:move_copy]
      campaigns = Campaign.find(params[:move_copy_to_select])
      unless campaigns.empty?
        campaigns.each{|campaign| @craft.move_to campaign, :replace => true, :copy => true} #for either copy or move perform the copy to all selected campaigns
        @craft.move_to(campaigns.last, :replace => true, :copy => false) if params[:commit].downcase.eql?("move") 
        #if it was a move, redo the move to the last campaign with copy=>false.  Using copy=>false for a group of campaigns won't work as the first one would 
        #delete the craft file and set the craft object as deleted.
      end
    end

    #updating commit message - prob also move this to spearate controller
    if params[:update_message]
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
          @craft = campaigns.first.craft.where(:name => @craft.name).first if params[:move_copy] && params[:commit].downcase.eql?("move")
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
