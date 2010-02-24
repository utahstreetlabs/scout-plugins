require File.dirname(__FILE__) + '/spec_helper'

describe MonitorDelayedJobs, 'build_report' do
  
  def use_transactional_fixtures
    false
  end
  
  before(:each) do
    DelayedJob.delete_all
    @scout_plugin = MonitorDelayedJobs.new Time.now, nil, 'path_to_app' => RAILS_ROOT, 'rails_env' => 'test'
    @scout_plugin.stub :report => nil
  end
  
  after(:each) do
    DelayedJob.delete_all
  end
  
  it "should report the total number of jobs" do
    2.times {DelayedJob.create!}
    @scout_plugin.should_receive(:report).with("No. of Jobs" => 2)
    @scout_plugin.build_report
  end

  it "should report the total number of jobs for each priority" do
    2.times {DelayedJob.create! :priority => 10}
    DelayedJob.create! :priority => 5
    @scout_plugin.should_receive(:report).with("Priority 10 Jobs" => 2)
    @scout_plugin.should_receive(:report).with("Priority 5 Jobs" => 1)
    @scout_plugin.build_report
  end
end