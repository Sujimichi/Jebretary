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
    unless @craft.deleted?
      @sha_id = params[:sha_id]
      history = @craft.history
      @commit = history.select{|commit| commit.sha == @sha_id}.first
      @revert_to_version = history.reverse.index(@commit) + 1
    else

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
    history = @craft.history
    if params[:commit_to_edit] && params[:update_message]
      commit = history.select{|h| h.sha.eql?(params[:commit_to_edit])}.first
      @craft.change_commit_message commit, params[:update_message]
    end
    if params[:sha_id] && history.map{|h| h.sha}.include?(params[:sha_id])
      past_version = history.select{|h| h.sha.eql?(params[:sha_id])}.first
      @craft.commit #ensure current version is commited before reverting
      @craft.revert_to past_version
    end
    if @craft.deleted? && params[:recover_deleted]
      @craft.recover
    end
    respond_with(@craft) do |f|
      f.html{
        if params[:return_to] && params[:return_to] == "campaign"
          redirect_to @craft.campaign
        else
          redirect_to @craft
        end
      }
      f.js {}
    end

  end
end
