class WelcomeController < ApplicationController
  def index
    @instances = Instance.all
    @thread = ENV["thread_active"]
  end
end
