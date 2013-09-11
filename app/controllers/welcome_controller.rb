class WelcomeController < ApplicationController
  require 'assets/version'
  def index
    @version = Jebretary::VERSION
    @instances = Instance.all
  end


  def update
    if params[:reset_help]
      system.config_set :seen_elements, []
      notice = "Help Tips Reset"
    end
    redirect_to :root, :notice => notice
  end
end
