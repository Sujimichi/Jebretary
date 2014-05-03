class CraftFileReader
  attr_accessor :parts, :details, :missing, :found, :mods

  def initialize craft, args = {:load_data => false, :read_file => true}
    if args[:read_file]
      data = File.open(File.join([craft.crafts_campaign.path, craft.file_name]), 'r'){|f| f.readlines}   
      read_part_names data
    end
    set_data(craft.part_data) if args[:load_data]
  end

  #Detects parts in .craft file and returns array of unique part names
  #(also sets @all_parts to list all the part names
  def read_part_names data
    part_names = data.select{ |line| line.match(/^\tpart =/) } #select the lines which start \tpart =     
    @parts = part_names.map{|name|                          #remove preceding and trailing text      
      p = name.sub("\tpart = ","").gsub("\"", "").split("_")    #remove preceding text and split on '_'
      p[0].chomp                 
    }
  end

  def count
    @parts.count
  end

  def stock?
    return true if @stock
    false
  end

  def missing?
    !@missing.empty?
  end

  def locate_in game_parts_db
    @details = @parts.map do |part|
      used_part = game_parts_db.locate(part)
      #used_part = game_parts_db.locate(part.gsub(".","_")) unless used_part #some parts have '.' in the craft file but '_' in the part name
      used_part = game_parts_db.locate(part.gsub(" ",""))  unless used_part #some parts have ' ' in the craft file but no space in the part name
      used_part = {:name => part, :dir => "not found", :not_found => true} unless used_part#in the case a part can not be located in the PartDB
      used_part      
    end
    @missing = @details.select{|p| p[:not_found]}.map{|p| p[:name]}.uniq.sort
    @found =   @details.select{|p| !p[:not_found]}
    @stock = @missing.empty? && @found.map{|p| p[:stock]}.all?
    @mods = @found.map{|p| p[:mod]}.uniq.select{|m| !m.eql?("Squad")}
    true
  end

  def set_data data
    @missing = data[:missing_parts]
    @found  =  data[:parts]
    @stock  =  data[:stock]
    @mods   =  data[:mods]
  end

end
