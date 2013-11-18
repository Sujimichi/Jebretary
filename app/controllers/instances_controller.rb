class InstancesController < ApplicationController

  respond_to :html, :js


  def index
    @instances = Instance.all
  end

  def create
    #raise params.inspect
    #/home/sujimichi/Share/KSPv0.19.1
    #r:\\Games\\KSPv0.19.1
    #params[:full_path] = "r:\\Games\\KSPv0.19.1"
    #params[:full_path] = "/home/sujimichi/Share/KSPv0.19.1"

    full_path = params[:full_path]
    if full_path.include?("/")
      full_path = full_path.split("/")
    elsif full_path.include?("\\")
      full_path = full_path.split("\\")
    else
      full_path = "error"
    end

    @instance = Instance.new(:full_path => full_path.to_json)

    begin
      files = Dir.open(File.join(full_path)).to_a
      raise "nothing found" if files.blank?
    rescue
      @instance.errors.add(:base, "unable to open directory '#{params[:full_path]}'")
    end
    @instance.errors.add(:base, "couldn't locate KSP.exe") if !files.blank? && !files.include?("KSP.exe")


    respond_with(@instance) do |f|      
      if @instance.errors.empty?
        @instance.save
        f.js { }
      else
        f.html { render :action => "new", :status => 422 }
      end
    end
  end

  def show
    respond_to do |f|           
      f.html{
        @instance = Instance.find(params[:id])
        unless @instance.campaigns.empty?
          @instance.prepare_campaigns
          @campaigns = @instance.reload.campaigns
          @campaigns.select{|c| c.exists? }.each{|c| c.set_flag}
        end
      }
      f.js  {
        ensure_no_db_lock do 
          @instance = Instance.find(params[:id])
          @campaigns = @instance.campaigns.select{|c| c.exists?}
        end      
      }
    end
  end

  def destroy
    @instance = Instance.find(params[:id])
    @instance.destroy
    respond_to do |format|
      format.html { redirect_to :back }
    end
  end  

  protected

  def action_when_locked status
    unless status.blank?
      data = JSON.parse(status) unless status.blank?
      @background_process = data[params[:id]] if data[params[:id]]
    end
    @flags = Dir.entries(File.join([Rails.root,"public"])).select{|f| f.include?("flag_for_campaign")}.map{|f| f.sub("flag_for_campaign_","").sub(".png","").to_i}.to_json
    @background_process ||= "waiting"
  end

end
