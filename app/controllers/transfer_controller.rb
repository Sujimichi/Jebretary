class TransferController < ApplicationController

  def edit
    respond_to do |f|
      f.js{
        @craft = Craft.find(params[:id])    
        @instances = Instance.all
        @sync_targets = @sync_targets = @craft.sync_targets
      }
    end

  end

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
          #@craft = campaigns.first.craft.where(:name => @craft.name).first
        end
        notice = "#{@craft.name} has been #{action_past_tense[action_type]} to #{campaigns.map{|c| c.name}.and_join}"
        notice = "#{@craft.name} was not #{action_past_tense[action_type]} to campaigns it is already sync'd with" if campaigns.empty?
      else
        error = "No destination campaingns where selected. #{@craft.name} was not #{action_past_tense[action_type]}"
      end


    when "sync"
      cur_list = @craft.sync[:with]
      @craft.sync = {:with => campaigns.map{|c| c.id} }
      
      @craft.save
      @craft.synchronize
      notice = "#{@craft.name} will now be sync'd with #{campaigns.map{|c| c.name}.and_join}"
      notice = "No destination campaigns where selected." if campaigns.blank?
      notice = "#{@craft.name} will no longer be sync'd with other campaigns" if @craft.sync[:with].blank? && !cur_list.blank?      
    end


    redirect_to :back, :notice => notice, :alert => error
  end

end
