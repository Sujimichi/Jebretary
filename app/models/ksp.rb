class KSP
 
  def self.controller
    if RUBY_PLATFORM =~ /mswin|mingw|cygwin/
      require 'win32ole'
      KSP::Windows
    else
      KSP::LinuxDev
    end
  end
 
end

class KSP::LinuxDev

  def self.find_running_instances
    []
  end

  def self.start
    return true
  end

end

class KSP::Windows
  
  def self.find_running_instances
    win32 = WIN32OLE.connect("winmgmts:\\\\.").InstancesOf("win32_process")
    processes = []
    win32.each{|process| processes << process}
    ksp_instances = processes.select{|p| p.name.downcase.eql?("ksp.exe")}
  end

  def self.start path
    path = File.join([path, "ksp.exe"])
    system "start #{path}"
  end

  def self.path_of_running_instances
    find_running_instances.map{|instance|
      File.join(instance.executablepath.split("\\"))
    }    
  end

  def select_instance path = nil
    instances = find_running_instances
    return nil if instances.empty?
    return instances.first unless path
    selected = instances.select{|inst| File.join(inst.executablepath.downcase.split("\\")).to_s.include?(path.to_s.downcase)}
    selected.first   
  end

  def terminate args = nil
    if args.is_a?(String) #assume it is a path
      instances = [select_instance(args)]
    elsif args.is_a?(WIN32OLE)
      instances = [args]  #or it is a WIN32OLE instance
    else
      instances = find_running_instances #otherwise select all running instances
    end
    instances.each{|instance| instance.terminate}
  end

end
