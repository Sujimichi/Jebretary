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
end
