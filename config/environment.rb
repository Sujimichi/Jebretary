# Load the rails application
require File.expand_path('../application', __FILE__)

ActiveSupport::Inflector.inflections do |inflect|
  inflect.irregular 'save', 'saves' #otherwise rails takes saves and singularizes it to safe.
end

# Initialize the rails application
Jebretary::Application.initialize!


