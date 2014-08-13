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
    #return ["/home/sujimichi/KSP/KSPv0.23.0-Mod"]
    #return ["/home/sujimichi/KSP/KSPv0.22.0-Stock"]
    []
  end

  def self.start path, x64_mode = false
    return true
  end

  def self.terminate arg = nil
    return true
  end

end

class KSP::Windows

  def self.find_running_instances
    win32 = WIN32OLE.connect("winmgmts:\\\\.").InstancesOf("win32_process")
    processes = []
    win32.each{|process| processes << process}
    ksp_instances = processes.select{|p| p.name.downcase.eql?("ksp.exe") || p.name.downcase.eql?("ksp_x64.exe")}
  end

  def self.start path, x64_mode = false
    ksp_path = x64_mode ? File.join([path, "ksp_x64.exe"]) : File.join([path, "ksp.exe"])
    system "start \"\" \"#{ksp_path}\"" if File.exists?(ksp_path) 
  end

  def select_instance path = nil
    instances = find_running_instances
    return nil if instances.empty?
    return instances.first unless path
    selected = instances.select{|inst| File.join(inst.executablepath.downcase.split("\\")).to_s.include?(path.to_s.downcase)}
    selected.first
  end

  def self.terminate args = nil
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
