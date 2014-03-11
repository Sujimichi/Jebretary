class CraftFileReader

  def initialize path
    @data = File.open(path, 'r'){|f| f.readlines}   
  end

  def parts

    @part_names = read_part_names
    
  end

  #Detects parts in .craft file and returns array of unique part names
  #(also sets @all_parts to list all the part names
  def read_part_names
    part_names = @data.select{ |line| line.match(/^\tpart =/) } #select the lines which start \tpart =     
    @all_parts = part_names.map{|name|                          #remove preceding and trailing text      
      p = name.sub("\tpart = ","").gsub("\"", "").split("_")    #remove preceding text and split on '_'
      p[0].chomp                 
    }.uniq
  end

end
