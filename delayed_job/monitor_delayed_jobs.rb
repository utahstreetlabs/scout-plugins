
class MonitorDelayedJobs < Scout::Plugin
  needs 'activerecord', 'yaml'
  
  require 'activerecord'

  class DelayedJob < ActiveRecord::Base; end
  
  def build_report
    db_config = YAML::load(File.open(@options['path_to_app'] + '/config/database.yml'))
    ActiveRecord::Base.establish_connection(db_config[@options['rails_env']])
    
    # ALl jobs
    report :total     => DelayedJob.count
    # Jobs that are currently being run by workers
    report :running   => DelayedJob.count(:conditions => 'locked_at IS NOT NULL')
    # Jobs that are ready to run but haven't ever been run
    report :waiting   => DelayedJob.count(:conditions => [ 'run_at <= ? AND locked_at IS NULL AND attempts = 0', Time.now.utc ])
    # Jobs that haven't ever been run but are not set to run until later
    report :scheduled => DelayedJob.count(:conditions => [ 'run_at > ? AND locked_at IS NULL AND attempts = 0', Time.now.utc ])
    # Jobs that aren't running that have failed at least once
    report :failing   => DelayedJob.count(:conditions => 'attempts > 0 AND failed_at IS NULL AND locked_at IS NULL')
    # Jobs that have permanently failed
    report :failed    => DelayedJob.count(:conditions => 'failed_at IS NOT NULL')
    
    # The oldest job that hasn't yet been run, in minutes
    if oldest = DelayedJob.find(:first, :conditions => [ 'run_at <= ? AND locked_at IS NULL AND attempts = 0', Time.now.utc ], :order => :run_at)
      report :oldest => (Time.now.utc - oldest.run_at) / 60
    else
      report :oldest => 0
    end
  end
end
