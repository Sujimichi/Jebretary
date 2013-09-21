class ApplicationController < ActionController::Base
  include Exceptional

  protect_from_forgery

  helper_method :system, :h_truncate, :truncated_link_to

  unless Rails.application.config.consider_all_requests_local #|| Rails.env.eql?("development") 
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
  end


  private

  def system
    return @system if defined?(@system) && !@system.nil?
    @system = System.new
  end

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


  #makes a div with truncated text that has a onhover title containing the untruncated text, truncate length is 40 by default
  # eg: h_truncate project.name
  # h_truncate project.name, :truncate => 50
  def truncated_text_with_hover text, args = {:truncate => 40}
    "<div title='#{text.length > args[:truncate] ? text : nil}'>#{text.truncate(args[:truncate])}</div>".html_safe
  end
  alias h_truncate truncated_text_with_hover

  def truncated_link_to text, path, args = {:truncate => 40}
    "<a href='#{path}' title='#{text.length > args[:truncate] ? text : nil}'>#{text.truncate(args[:truncate])}</a>".html_safe
  end

end
