class ApplicationController < ActionController::Base
  protect_from_forgery
  
  
  private

  def ensure_no_db_lock &blk
    Dir.chdir(System.root_path)
    if File.exist?("#{Rails.env}_db_access")
      status = File.open("#{Rails.env}_db_access", 'rb') {|f| f.readlines }.join
      action_when_locked status
    else
      yield
    end
  end

  def action_when_locked status
    @background_process = "waiting"
  end

end
