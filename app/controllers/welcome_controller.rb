class WelcomeController < ApplicationController
  require 'assets/version'
  def index
    @version = Jebretary::VERSION
    @instances = Instance.all
    @stock_parts = System.new.get_config["stock_parts"]
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
      notice = "Parts in #{new_stock_parts.and_join} are now considered stock"
    end
    if params[:reset_help]
      system.config_set :seen_elements, []
      notice = "Help Tips Reset"
    end
    redirect_to :root, :notice => notice
  end
end
