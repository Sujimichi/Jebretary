class ApplicationController < ActionController::Base
  protect_from_forgery
  
  
  private

  def ensure_no_db_lock &blk
    Dir.chdir(File.join([Rails.root, ".."]))
    if File.exist?("db_access")
      status = File.open("db_access", 'r') {|f| f.readlines }.join
      action_when_locked status
    else
      yield
    end
  end

  def action_when_locked status
    @background_process = "waiting"
  end

end
