class ApplicationController < ActionController::Base
  include Exceptional
  
  protect_from_forgery
   
  
  #unless Rails.application.config.consider_all_requests_local #|| Rails.env.eql?("development") 
  rescue_from( Exception                            ) { |error| render_error(500, error) }  #unless Rails.env.eql?("development") 
  rescue_from( RuntimeError                         ) { |error| render_error(500, error) }  #unless Rails.env.eql?("development") 


  rescue_from( Exceptional::NotAuthenticated        ) { |error| render_error(401, error) }
  rescue_from( Exceptional::Unauthorized            ) { |error| render_error(401, error) }
  rescue_from( Exceptional::BetaFeature             ) { |error| render_error(503, error, '503_beta') }
  rescue_from( Exceptional::NotAllowed              ) { |error| render_error(404, error) }
  rescue_from( Exceptional::DevsOnly                ) { |error| render_error(307, error, 'developers_only') }
  rescue_from( Exceptional::AccountBlocked          ) { |error| render_error(403, error, '403_account_disabled') }    

  rescue_from( ActiveRecord::RecordNotFound         ) { |error| render_error(404, error) }    
  rescue_from( ActionController::RoutingError       ) { |error| render_error(404, error) }
  rescue_from( AbstractController::ActionNotFound   ) { |error| render_error(404, error) }
  rescue_from( ActionController::UnknownController  ) { |error| render_error(404, error) }

  #Errors to still hook:
  #ActiveRecord::StatementInvalid: SQLite3::BusyException: database is locked
  #end
 
  
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
