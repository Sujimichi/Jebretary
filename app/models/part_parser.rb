class PartParser

  class LegacyPartException  < StandardError; end 
  class UnknownPartException < StandardError; end


  require 'json'
  attr_accessor :parts, :resources, :internals, :props

  def initialize dir, args = {:source => :game_folder, :write_to_file => false}
    begin
      @stock_parts = System.new.get_config["stock_parts"]
    rescue
      @stock_parts = ["Squad", "NASAmission"]
    end
    @instance_dir = dir
    if args[:source] == :game_folder
      cur_dir = Dir.getwd
      Dir.chdir(@instance_dir)
      index_parts
      #puts "Done\n"
      #puts "ignored #{@ignored_cfgs}"    
      #puts "\n\nBuilding associations, please wait...\n\n"
      @parts ||= {}
      associate_components  
      write_to_file if args[:write_to_file]
      Dir.chdir(cur_dir)
    else
      read_from_file 
    end
  end

  def read_from_file
    data = File.open(File.join([@instance_dir, "jebretary.partsDB"]),'r'){|f| f.readlines.join }
    parts_from_file = HashWithIndifferentAccess.new(JSON.parse(data))
    @parts = parts_from_file[:parts]
    @resources = parts_from_file[:resources]
    @internals = parts_from_file[:internals]
    @props = parts_from_file[:props]
    @ignored_cfgs = parts_from_file[:ignored_cfgs]
  end

  def write_to_file
    File.open(File.join([@instance_dir, "jebretary.partsDB"]),'w'){|f| f.write self.to_json}
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
      part_info = {:dir => dir, :path => cfg_path }

      if cfg_path.match(/^GameData/)
        folders = dir.split("/")
        mod_dir = folders[1] #mod dir is the directory inside GameData

        part_info.merge!(:mod => mod_dir)
        part_info.merge!(:stock => true) if @stock_parts.include?(mod_dir)
   
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

        #subcompnents deals with when a .cfg includes info for more than one part or resouce etc.
        cfg.split( first_significant_line ).map do |sub_component|
          next if sub_component.blank?
          name = sub_component.select{|line| line.include?("name =")}.first
          next if name.blank?
          name = name.sub("name = ","").gsub("\t","").gsub(" ","").chomp         
          part_info.merge!(:name => name)
          
          if type.eql?(:resource)            
            @resources.merge!(name => part_info.clone)
            nil
          elsif type.eql?(:internal)
            part_info.merge!(:file => cfg)
            @internals.merge!(name => part_info.clone)
            nil
          elsif type.eql?(:prop)
            @props.merge!(name => part_info.clone)
            nil
          else #its a part init'
            part_info.merge!(:file => cfg)
            part_info.clone #return part info in the .map loop
          end
        end.compact

      elsif cfg_path.match(/^Parts/)
        part_info.merge!(:name => part_name, :legacy => true, :type => :part, :mod => :unknown_legacy)
        part_info
      else
        raise UnknownPartException, "part #{cfg_path} is not in either GameData or the legacy Parts folder"
        #this could be a problem for people with legacy internals, props or resources
      end

    end.flatten.compact
    @parts = part_info.map{|n| {n[:name] => n} }.inject{|i,j| i.merge(j)}
  end

  def associate_components
    #associate internals and resources with parts
    @parts.each do |name, data|
      data[:internals] = associate_component(data[:file], @internals)
      data[:resources] = associate_component(data[:file], @resources)
      data.delete(:file)
    end
    #associate props with internals
    @internals.each do |name, data| 
      data[:props] = associate_component(data[:file], @props) 
      data.delete(:file)
    end
  end

  #given the cfg_file of a part or internal and a group of sub comonents (internals, resources, props) 
  #it searches throu the cfg_file and finds references to the sub comonents
  def associate_component cfg_file, components
    components.select{|name, data|
      cfg_file.select{|l| !l.match("//") && l.include?("name") && l.include?("=") }.map{|l| l.match(/\s#{name}\s/)}.any?
    }.map{|name, data| name}
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

