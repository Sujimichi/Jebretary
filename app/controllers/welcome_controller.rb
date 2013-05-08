class WelcomeController < ApplicationController
  def index
    @instances = Instance.all
  end
end
