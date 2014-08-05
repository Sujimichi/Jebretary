class MoveCraftController < ApplicationController

  def update

    @craft = Craft.find(params[:id])    
    begin
      campaign_ids = JSON.parse(params[:selected_campaigns])
    rescue
      campaign_ids = []
    end       
    campaigns = Campaign.find(campaign_ids)

    action_type = params[:commit].downcase
    action_past_tense = {"move" => "moved", "copy" => "copied"}

    cur_list = @craft.sync[:with]
    #raise params.inspect

    case action_type
    when "move", "copy"

      unless campaigns.empty?
        campaigns = campaigns.select{|c| !cur_list.include?(c.id)}
                
        campaigns.each{|campaign| @craft.move_to campaign, :replace => true, :copy => true} #for either copy or move perform the copy to all selected campaigns
        if action_type.eql?("move")
          @craft.move_to(campaigns.last, :replace => true, :copy => false)
          #if it was a move, redo the move to the last campaign with copy=>false.  Using copy=>false for a group of campaigns won't work as the first one would 
          #delete the craft file and set the craft object as deleted.
          @craft = campaigns.first.craft.where(:name => @craft.name).first
        end
        notice = "Craft has been #{action_past_tense[action_type]} to #{campaigns.map{|c| c.name}.and_join}"
      else
        error = "no destination campaingns where selected. Craft was not #{action_past_tense[action_type]}"
      end
      

    when "sync"
      cur_list = @craft.sync[:with]
      @craft.sync = {:with => campaigns.map{|c| c.id} }
      @craft.save
      @craft.synchronize
      notice = "craft will now be sync'd with #{campaigns.map{|c| c.name}.and_join}"
      notice = "no destination campaigns where selected. Craft will not be sync'd" if campaigns.blank?
      notice = "craft will no longer be sync'd with other campaigns" if @craft.sync[:with].blank? && !cur_list.blank?      
    end


    redirect_to @craft, :notice => notice, :alert => error
  end

end
