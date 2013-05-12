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
    @craft = Craft.find(params[:id])
    respond_with(@craft) do |f|
      f.html{}
      f.js{
        @history = @craft.history
      }
    end
  end

  def edit
    @craft = Craft.find(params[:id])
    @sha_id = params[:sha]
    @commit = @craft.history.select{|commit| commit.sha == @sha_id}.first
    respond_with(@craft) do |f|
      f.html{}
    end
  end

  def update
    @craft = Craft.find(params[:id])
    history = @craft.history
    if params[:sha_id] && history.map{|h| h.sha}.include?(params[:sha_id])
      past_version = history.select{|h| h.sha.eql?(params[:sha_id])}
      @craft.commit #ensure current version is commited before reverting
      @craft.revert_to past_version
    end
    respond_with(@craft) do |f|
      f.html{
        redirect_to @craft
      }
    end

  end
end
