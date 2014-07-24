class WelcomeController < ApplicationController
  require 'assets/version'
  def index
    @version = Jebretary::VERSION
    @instances = Instance.all
    
    @config = System.new.get_config
    @config["show_error_report"] = true if @config["show_error_report"].nil?
  end

  def edit
    respond_to do |f|
      f.js{
        if params[:open_root_folder]
          path = System.root_path
          begin 
            if RUBY_PLATFORM =~ /mswin|mingw|cygwin/
              `start explorer.exe #{path.split("/").join("\\")}`
            else
              `nautilus #{path}`
            end      
          rescue
          end
        end
        if params[:reset_log]
          path = File.join([System.root_path, "error.log"])   
          File.open(path, "w"){|f| f.write ""}
        end
        return render :text => "ok"
      }
    end
  end

  def update
    if params[:stock_parts]
      sys = System.new
      current_stock_parts = sys.get_config["stock_parts"].map{|i| i.strip}
      new_stock_parts = params[:stock_parts].split(",").map{|i| i.strip}.select{|i| !i.blank?}
      changes = [current_stock_parts - new_stock_parts, new_stock_parts - current_stock_parts].flatten.uniq

      effected_craft = Craft.all.select{|c| c.part_data.has_key?("mods")}.select{|c| 
        changes.map{|mod| c.part_data["mods"].include?(mod)}.any?
      }
      effected_craft.each{|c| c.update_part_data}

      sys.config_set "stock_parts", new_stock_parts
      notice = "Parts in #{new_stock_parts.and_join} are now considered stock.  Part data on #{effected_craft.count} craft have been updated"
    end
    if params[:reset_help]
      system.config_set :seen_elements, []
      notice = "Help Tips Reset"
    end
    if params.has_key?(:error_reporting)
      system.config_set :show_error_report, params[:error_reporting].eql?("true")
      notice = "Error reporting is now #{params[:error_reporting].eql?("true") ? 'On' : 'Off'}"
    end
    if params[:update_parts_db_on_load]
      system.config_set :update_parts_db_on_load, params[:update_parts_db_on_load].eql?("true")
      notice = "Updating Part DBs on load is now #{params[:update_parts_db_on_load].eql?("true") ? 'On' : 'Off'}"
    end
    redirect_to :root, :notice => notice
  end
end
