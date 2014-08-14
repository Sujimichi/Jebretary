class CampaignsController < ApplicationController

  respond_to :html, :js

  def index
    @campaigns = Campaign.all
    respond_with(@campaigns) do |f|
      f.html{}
    end
  end

  def show
    respond_with(@campaign) do |f|
      f.js{
        ensure_no_db_lock do 
          @campaign = Campaign.find(params[:id])

          @new_and_changed = @campaign.new_and_changed
          @current_project = @campaign.last_changed_craft(@new_and_changed)        
          @saves = @campaign.save_history(:limit => 5)
          @campaign_commit_messages = @campaign.commit_messages
          @repo = @campaign.repo 

       
          #generate a checksum based on items that imply a need to update the page. The checksum will be stored so subsiquent requests
          #can be compaired.  If the checksums match then there is no need to update the page.
          begin
            current_craft_file =  Digest::SHA256.hexdigest( File.open(@current_project.file_path, 'r'){|f| f.readlines}.join )
          rescue
            current_craft_file = ""
          end

          
          state = [current_craft_file, @campaign, @campaign.has_untracked_changes?, @repo.log(:limit => 1).first.to_s, @current_project, @saves, params[:sort_opts],  params[:search_opts]].to_json
          state = Digest::SHA256.hexdigest(state)
          
          if Rails.cache.read("state_stamp") != state || !Rails.cache.read("last_controller").eql?("CampaignsController")
            @current_project_history = @current_project.history(:limit => 5) if @current_project
            @most_recent_commit = @campaign.latest_commit(@current_project, @saves, @new_and_changed)
            @deleted_craft_count = [@campaign.craft.where(:deleted => true), @campaign.subassemblies.where(:deleted => true)].flatten.count

            
            
            params[:sort_opts][:vab] ||= "updated_at reverse"
            params[:sort_opts][:sph] ||= "updated_at reverse"
            sort_opts = params[:sort_opts]
            
            @craft_for_list = {}
            [:vab, :sph].each do |type|
              sort_by = sort_opts[type].sub("reverse", "").strip
              reverse_order = sort_opts[type].include?('reverse')

              unless params[:search_opts][type].empty?
                @craft_for_list[type] = @campaign.craft.where(:craft_type => type.to_s).where("LOWER(name) LIKE :query", {:query => "%#{params[:search_opts][type].downcase}%"}).order(sort_by)
              else
                @craft_for_list[type] = @campaign.craft.where(:craft_type => type.to_s).order(sort_by)
              end
              @craft_for_list[type].reverse! if reverse_order
            end

            @subassemblies = @campaign.subassemblies.order(:name)

            @campaign.update_attributes(:sort_options => params[:sort_opts].to_json) unless @campaign.sort_options.eql?(params[:sort_opts].to_json)           
            @current_project_commit_messages = @current_project.commit_messages if @current_project
            
          else
            return render :partial => "no_update"
          end

          Rails.cache.write("state_stamp", state)          
        end
      }
      f.html{
        @campaign = Campaign.find(params[:id])
        Rails.cache.delete("state_stamp")
        if @campaign.sort_options.blank?
          @campaign.update_attributes(:sort_options => {:vab => "updated_at reverse", :sph => "updated_at reverse"}.to_json)
        end
      }
    end
  end

  def destroy
    @campaign = Campaign.find(params[:id])
    @campaign.destroy
    respond_to do |format|
      format.html { redirect_to :back }
    end
  end

end
