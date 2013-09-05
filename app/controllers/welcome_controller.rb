class WelcomeController < ApplicationController
  require 'assets/version'
  def index
    @version = Jebretary::VERSION
    @instances = Instance.all
  end
end
