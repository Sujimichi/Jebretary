class ApplicationController < ActionController::Base
  include Exceptional

  protect_from_forgery

  helper_method :system, :h_truncate, :truncated_link_to, :time_ago

  #if Rails.env.eql?("production") 
    rescue_from( Exception                            ) { |error| render_error(500, error) }  #unless Rails.env.eql?("development") 
    rescue_from( RuntimeError                         ) { |error| render_error(500, error) }  #unless Rails.env.eql?("development") 

    rescue_from( Exceptional::NotAuthenticated        ) { |error| render_error(401, error) }
    rescue_from( Exceptional::Unauthorized            ) { |error| render_error(401, error) }
    rescue_from( Exceptional::NotAllowed              ) { |error| render_error(404, error) }

    rescue_from( ActiveRecord::RecordNotFound         ) { |error| render_error(404, error) }    
    rescue_from( ActionController::RoutingError       ) { |error| render_error(404, error) }
    rescue_from( AbstractController::ActionNotFound   ) { |error| render_error(404, error) }
    rescue_from( ActionController::UnknownController  ) { |error| render_error(404, error) }

    #Errors to still hook:
    #ActiveRecord::StatementInvalid: SQLite3::BusyException: database is locked
 #end


  private

  def system
    return @system if defined?(@system) && !@system.nil?
    @system = System.new
  end

  def ensure_no_db_lock &blk
    Dir.chdir(System.root_path)
    if system_monitor_running?
      status = File.open("#{Rails.env}_db_access", 'rb') {|f| f.readlines }.join
      action_when_locked status
    else
      yield
    end
  end

  def action_when_locked status
    @background_process = "waiting"
  end

  def system_monitor_running?
    File.exist?("#{Rails.env}_db_access")
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

  def time_ago time
    seconds_ago = Time.zone.now.to_time - time.to_time
    seconds_ago += Time.now.utc_offset

    days_ago = (seconds_ago / 86400).floor
    remaining_seconds = seconds_ago - (days_ago * 86400)
    
    hours_ago = (remaining_seconds / 3600).floor
    remaining_seconds = remaining_seconds - (hours_ago * 3600)

    minutes_ago = (remaining_seconds / 60).floor
    remaining_seconds = remaining_seconds - (minutes_ago * 60)

    seconds_ago = remaining_seconds.round

    text = ""
    if days_ago != 0
      text = "#{days_ago} days, #{hours_ago} hours"
    elsif hours_ago != 0 
      if hours_ago == 1 && minutes_ago != 0
        text = "#{hours_ago} hour, #{minutes_ago} mins"
      else
        text = "about #{hours_ago} hours"
      end
    elsif minutes_ago != 0
      if minutes_ago == 1
        text = "#{minutes_ago} min, #{seconds_ago} seconds"
      elsif minutes_ago < 30
        text = "#{minutes_ago} mins, #{seconds_ago} seconds"
      else
        text = "about #{minutes_ago} mins"
      end
    else
      text = "#{seconds_ago} seconds"
    end
    text

  end


end
