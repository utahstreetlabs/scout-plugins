
class MonitorDelayedJobs < Scout::Plugin
  needs 'activerecord', 'yaml'
  
  require 'activerecord'

  class DelayedJob < ActiveRecord::Base; end
  
  def build_report
    db_config = YAML::load(File.open(@options['path_to_app'] + '/config/database.yml'))
    ActiveRecord::Base.establish_connection(db_config[@options['rails_env']])
    
    report :total     => DelayedJob.count
    report :running   => DelayedJob.count(:conditions => 'locked_at IS NOT NULL')
    report :waiting   => DelayedJob.count(:conditions => [ 'run_at <= ? AND locked_at IS NULL', Time.now.utc ])
    report :scheduled => DelayedJob.count(:conditions => [ 'run_at > ? AND locked_at IS NULL', Time.now.utc ])
    report :failing   => DelayedJob.count(:conditions => 'attempts > 0')
    report :failed    => DelayedJob.count(:conditions => 'failed_at IS NOT NULL')
    
    if oldest = DelayedJob.find(:first, :conditions => [ 'run_at <= ? AND locked_at IS NULL', Time.now.utc ], :order => :id)
      report :oldest => (Time.now.utc - oldest.created_at) / 60
    else
      report :oldest => 0
    end
  end
end
