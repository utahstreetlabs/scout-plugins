require 'rubygems'
require 'activerecord'
require 'yaml'

class DelayedJob < ActiveRecord::Base; end

class MonitorDelayedJobs < Scout::Plugin
  needs 'active_record', 'yaml'
  def build_report
    db_config = YAML::load(File.open(@options['path_to_app'] + '/config/database.yml'))
    ActiveRecord::Base.establish_connection(db_config[@options['rails_env']])
    
    report 'No. of Jobs' => DelayedJob.count
    
    jobs_by_prio.each do |job|
      report "Priority #{job.priority} Jobs" => job.count.to_i
    end
  end
  
  private
  
  def jobs_by_prio
    DelayedJob.all(:select => 'priority, count(1) AS count', :group => 'priority')
  end
end