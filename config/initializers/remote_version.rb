require 'assets/remote'
begin
  Jebretary::Application.config.remote_version = Remote.version    
rescue
  Jebretary::Application.config.remote_version = nil
end
