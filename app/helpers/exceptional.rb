module Exceptional

  
  class NotAuthenticated  < Exception; end
  class NotAllowed        < Exception; end
  class Unauthorized      < Exception; end

  class AccountBlocked    < Exception; end

  class BetaFeature < Exception
    attr_accessor :javascript
  end  

  class DevsOnly < Exception
    attr_accessor :javascript
  end

  #This is here to take requests from all Unmatched routes.  
  #It gets arround the problem in rails 3.0.1+ of rescue_from not handling ActionController::RoutingErrors thrown in the routes.
  #This enables an ActionController::RoutingError to be thrown and it is caught by rescue_from
  def raise_routing_error!
    raise ActionController::RoutingError.new("no route matches #{params[:unmatched_route]}")
  end

  private

  def render_error code = 500, exception = nil, template = nil
    #respond_to do |f| 
      @exception = exception
      template ||= code     
      System.log_error "Server Error:\n#{exception}\n#{exception.backtrace[0..4]}"
      begin
        return render :template => "errors/#{template}", :status => code 
      rescue
        return redirect_to :root, :alert => exception.message
      end
      
    #end
  end

  #Takes a Block to yield, but will call the not_found! redirect if the block throws an error.
  #Usage:
  #  not_found_rescue!(entities_path){ @entity = Entity.find(42)}
  def not_found_rescue! url= root_url,  &blk
    begin
      yield
    rescue ActiveRecord::RecordNotFound => error
      render_error(404, error)
    end
  end

  def end_session!
    sign_out current_user if current_user
  end

  #===============================\
  #==Exceptions with JS============>
  #===============================/

  def developers_only! 
    end_session!
    exception = Exceptional::DevsOnly.new("The System is currently offline for development, please contact Team::Dev")
    exception.javascript = "<script type='text/javascript'> setTimeout(function(){window.location.href = '/'}, 10000); </script>"
    raise exception
  end

  def beta_feature! redirect = root_path
    return if settings[:use_beta]
    name = self.class.to_s.underscore.sub("_controller","").pluralize.titlecase
    exception = Exceptional::BetaFeature.new("#{name} are a BETA feature.  You can enable beta features in your settings.")
    exception.javascript = "<script type='text/javascript'> panels['external_feeds_panel'].hide() </script>"
    raise exception
  end 

  #===============================\
  #==Basic Exceptions==============>
  #===============================/


  #Redirect to call when an object can not be found
  def not_found! redirect = root_path
    raise ActionController::RoutingError.new("Sorry, I could not find the requested item!")
  end  

  #Redriect to call when the requested action is not permitted
  def not_allowed! redirect = root_url
    raise Exceptional::Unauthorized.new("Sorry, I was could not perform the action you requested!")
  end

  #Redirect to call in cases of not finding an object or request not being permitted
  def unavailable! redirect = root_path
    raise Exceptional::NotAllowed.new("Sorry, I was unable to perform the action you requested!")
  end 

  #===============================\
  #==Login Based Exceptions========>
  #===============================/

  def must_be_logged_in! redirect = :root
    end_session!
    raise Exceptional::NotAuthenticated.new("You must be logged in to access this")
  end

  def must_be_logged_out! redirect = root_url
    raise Exceptional::NotAuthenticated.new("You must be logged OUT to access this")
  end

  def must_have_roles! roles, redirect = root_path
    raise Exceptional::Unauthorized.new("You do not have clearance to access this")
  end
  
  def authentication_failed!
    store_location
    raise Exceptional::NotAuthenticated.new("Your username and password where not recognised")
  end

  def account_blocked! redirect = :root
    end_session!
    raise Exceptional::AccountBlocked.new("This Account has been Disabled.  Please contact support.")
  end


end
