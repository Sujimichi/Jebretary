class CraftFileReader

  def initialize file_contents
    @data = file_contents
  end


end

class Parts
  require 'json'
  attr_accessor :parts

  def initialize dir = nil
    if dir
      cur_dir = Dir.getwd
      Dir.chdir(dir)
      index_parts
      puts "Done\n"
      puts "ignored #{@ignored_cfgs}"    
      puts "\n\nBuilding associations, please wait...\n\n"
      associate_components  
      Dir.chdir(cur_dir)
    end
  end

  def read_from_file parts_from_file
    parts_from_file = JSON.parse(parts_from_file)
    @parts = parts_from_file[:parts]
    @resources = parts_from_file[:resources]
    @internals = parts_from_file[:internals]
    @props = parts_from_file[:props]
    @ignored_cfgs = parts_from_file[:ignored_cfgs]
  end

  def discover_cfgs
    Dir.glob("**/*/*.cfg")      #find all the .cfg files
  end

  def index_parts 
    part_cfgs = discover_cfgs
    @resources = {}
    @internals = {}
    @props = {}
    @ignored_cfgs = []
    part_info = part_cfgs.map do |cfg_path|
      cfg = File.open(cfg_path,"r"){|f| f.readlines}
      begin
        part_name = cfg.select{|line| line.include?("name =")}.first.sub("name = ","").gsub("\t","").gsub(" ","").chomp
        print "."
      rescue
        @ignored_cfgs << cfg_path
        next
      end
      dir = cfg_path.sub("/part.cfg","")
      part_info = {:name => part_name, :dir => dir, :file => cfg, :path => cfg_path }

      if cfg_path.match(/^GameData/)
        folders = dir.split("/")
        mod_dir = folders[1] #mod dir is the directory inside GameData

        part_info.merge!(:mod => mod_dir)
        part_info.merge!(:stock => true) if mod_dir == "Squad"
        
        #determine the type of cfg file
        first_significant_line = cfg.select{|line| line.match("//").nil? && !line.chomp.empty? }.first #first line that isn't comments or empty space
        type = :part     if first_significant_line.match(/^PART/)
        type = :prop     if first_significant_line.match(/^PROP/)
        type = :internal if first_significant_line.match(/^INTERNAL/)
        type = :resource if first_significant_line.match(/^RESOURCE_DEFINITION/)
        type ||= :part #assume undetected headings will be parts
        part_info.merge!(:type => type)      
        
        #incases of a maim mod dir having sub divisions within it    
        sub_mod_dir = folders[2] if type.eql?(:part) && folders[2].downcase != "parts" 
        part_info.merge!(:sub_mod => sub_mod_dir) if sub_mod_dir

        if type.eql?(:resource)
          resources = cfg.select{|line| !line.match("//") && line.include?("name") && line.include?("=")}.map{|l| l.split("=").last.sub(" ","").chomp}
          resources.map{|r| @resources.merge!(r => part_info)}
          next
        elsif type.eql?(:internal)
          @internals.merge!(part_name => part_info)
          next
        elsif type.eql?(:prop)
          @props.merge!(part_name => part_info)
          next
        else #its a part init'
          part_info #return part info in the .map loop
        end

      elsif cfg_path.match(/^Parts/)
        part_info.merge!(:legacy => true , :type => :part, :mod => :unknown_legacy)
        part_info
      else
        raise "part #{cfg_path} is not in either GameData or the legacy Parts folder"
        #this could be a problem for people with legacy internals, props or resources
      end

    end.compact
    @parts = part_info.map{|n| {n[:name] => n} }.inject{|i,j| i.merge(j)}
  end

  def associate_components
    #associate internals and resources with parts
    @parts.each do |name, data|
      data[:internals] = associate_component(data[:file], @internals)
      data[:resources] = associate_component(data[:file], @resources)
    end
    #associate props with internals
    @internals.each{|name, data| data[:props] = associate_component(data[:file], @props) }
  end

  #given the cfg_file of a part or internal and a group of sub comonents (internals, resources, props) 
  #it searches throu the cfg_file and finds references to the sub comonents
  def associate_component cfg_file, components
    components.select{|name, data|
      cfg_file.select{|l| !l.match("//") && l.include?("name") && l.include?("=") }.map{|l| l.match(/\s#{name}\s/)}.any?
    }.map{|name, data| components[name]}
  end

  def locate part_name
    @parts[part_name]
  end

  def to_json
    {
      :parts => @parts,
      :resources => @resources,
      :internals => @internals,
      :props => @props,
      :ignored_cfgs => @ignored_cfgs
    }.to_json
  end

  def show
    puts @parts.to_json
  end

end

