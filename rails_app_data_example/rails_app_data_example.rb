# This is an example plugin for grabbing data from a Rails application and sending it to Scout. 
# Note that we are only loading ActiveRecord, not the entire Rails environment so we have a smaller footprint. 
# 
# To test:
#
# scout test rails_app_data_example/rails_app_data_example.rb path_to_app=APP_PATH

$VERBOSE=false # sometimes loading ActiveRecord can be noisy

class RailsAppDataExample < Scout::Plugin
  
  needs 'active_record', 'yaml', 'erb'
  require 'active_record'
  
  # define any AR models you need access to
  class User < ActiveRecord::Base; end
  
  OPTIONS=<<-EOS
  path_to_app:
    name: Full Path to the Rails Application
    notes: "The full path to the Rails application (ex: /var/www/apps/APP_NAME/current)."
  rails_env:
    name: Rails environment that should be used
    default: production
  EOS
  
  def build_report
    establish_connection
    
    report_hash = Hash.new
    
    # grab your datas!
    report_hash[:users] = User.count

    # send 'em to Scout!
    report(report_hash)
  end
  
  # establish a conection to AR with config options from the Rails App's database.yml file
  # and provided Rails Environment.
  def establish_connection
    app_path = option(:path_to_app)
    db_config_path = app_path + '/config/database.yml'
    db_config = YAML::load(ERB.new(File.read(db_config_path)).result)
    ActiveRecord::Base.establish_connection(db_config[option(:rails_env)])
  end
end