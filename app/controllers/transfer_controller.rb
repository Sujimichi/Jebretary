class TransferController < ApplicationController

  before_filter :assign_object, :only => [:edit, :update]


  def edit
    respond_to do |f|
      f.js{
        @instances = Instance.all
        @sync_targets = @sync_targets = @object.sync_targets
      }
    end
  end

  def update
    begin
      campaign_ids = JSON.parse(params[:selected_campaigns])
    rescue
      campaign_ids = []
    end       
    campaigns = Campaign.find(campaign_ids)

    action_type = params[:commit].downcase
    action_past_tense = {"move" => "moved", "copy" => "copied"}

    cur_list = @object.sync[:with]
    cur_list ||= []


    case action_type
    when "move", "copy"

      unless campaigns.empty?
        campaigns = campaigns.select{|c| !cur_list.include?(c.id)}

        campaigns.each{|campaign| @object.move_to campaign, :replace => true, :copy => true} #for either copy or move perform the copy to all selected campaigns
        if action_type.eql?("move")
          @object.move_to(campaigns.last, :replace => true, :copy => false)
          #if it was a move, redo the move to the last campaign with copy=>false.  Using copy=>false for a group of campaigns won't work as the first one would 
          #delete the craft file and set the craft object as deleted.
          #@object = campaigns.first.craft.where(:name => @object.name).first
        end
        notice = "#{@object.name} has been #{action_past_tense[action_type]} to #{campaigns.map{|c| c.name}.and_join}"
        notice = "#{@object.name} was not #{action_past_tense[action_type]} to campaigns it is already sync'd with" if campaigns.empty?
      else
        error = "No destination campaingns where selected. #{@object.name} was not #{action_past_tense[action_type]}"
      end


    when "sync"
      cur_list = @object.sync[:with]
      @object.sync = {:with => campaigns.map{|c| c.id} }

      @object.save
      @object.synchronize
      notice = "#{@object.name} will now be sync'd with #{campaigns.map{|c| c.name}.and_join}"
      notice = "No destination campaigns where selected." if campaigns.blank?
      notice = "#{@object.name} will no longer be sync'd with other campaigns" if @object.sync[:with].blank? && !cur_list.blank?      
    end


    redirect_to :back, :notice => notice, :alert => error
  end

  private

  def assign_object
    if params[:subassembly].eql?("true")
      @object = Subassembly.find(params[:id])
    else
      @object = Craft.find(params[:id])    
    end
  end
end
