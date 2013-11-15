class MoveCraftController < ApplicationController

  def update
    @craft = Craft.find(params[:id])    
    campaigns = Campaign.find(params[:move_copy_to_select])
    unless campaigns.empty?
      campaigns.each{|campaign| @craft.move_to campaign, :replace => true, :copy => true} #for either copy or move perform the copy to all selected campaigns
      @craft.move_to(campaigns.last, :replace => true, :copy => false) if params[:commit].downcase.eql?("move") 
      #if it was a move, redo the move to the last campaign with copy=>false.  Using copy=>false for a group of campaigns won't work as the first one would 
      #delete the craft file and set the craft object as deleted.
    end

    @craft = campaigns.first.craft.where(:name => @craft.name).first if params[:commit].downcase.eql?("move")
    redirect_to @craft    
  end

end
