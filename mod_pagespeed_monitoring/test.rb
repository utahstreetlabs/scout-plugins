require File.expand_path('../../test_helper.rb', __FILE__)
require File.expand_path('../mod_pagespeed_monitoring.rb', __FILE__)
require 'open-uri'

class ModPagespeedMonitoringTest < Test::Unit::TestCase

  def setup
    @options=parse_defaults("mod_pagespeed_monitoring")
    @stats = File.read(File.dirname(__FILE__)+"/fixtures/statistics.txt")
    @stats_with_histograms = File.read(File.dirname(__FILE__)+"/fixtures/stats_with_histograms.txt")
  end
  
  def teardown
    FakeWeb.clean_registry
  end
  
  def test_initial_runs
    uri=@options['url']
    FakeWeb.register_uri(:get, uri, :body => @stats)
    @plugin=ModPagespeedMonitoring.new(nil,{},@options)
    
    time = Time.now
    Timecop.travel(time-60*10) do 
      # no reports on initial run
      res = @plugin.run()
      assert res[:reports].empty?
      assert res[:memory].size <= 20
      res[:memory].each do |k,v|
        assert ModPagespeedMonitoring::TRACKED.include?(k.sub('_counter_',''))
      end
      
      Timecop.travel(time) do 
        @plugin=ModPagespeedMonitoring.new(time-60*10,res[:memory],@options)
        # reports on subsequent runs
        res = @plugin.run()
        assert_equal ModPagespeedMonitoring::TRACKED.size, res[:reports].size 
      end # now
    end # Timecop 
  end
  
  # Appears that newer versions of mod_pagespeed uses an HTML version of the stats page. Stats are embedded
  # inside PRE tags.
  def test_run_with_histograms
    uri=@options['url']
    FakeWeb.register_uri(:get, uri, :body => @stats_with_histograms)
    @plugin=ModPagespeedMonitoring.new(nil,{},@options)
    
    time = Time.now
    Timecop.travel(time-60*10) do 
      # no reports on initial run
      res = @plugin.run()
      assert res[:reports].empty?
      assert res[:memory].size <= 20
      res[:memory].each do |k,v|
        assert ModPagespeedMonitoring::TRACKED.include?(k.sub('_counter_',''))
      end
      
      Timecop.travel(time) do 
        @plugin=ModPagespeedMonitoring.new(time-60*10,res[:memory],@options)
        # reports on subsequent runs
        res = @plugin.run()
        assert_equal 7, res[:reports].size # has a subset of reports
      end # now
    end # Timecop
  end
  
  def test_connection_refused
    @plugin=ModPagespeedMonitoring.new(nil,{},@options)
    res = @plugin.run()
    assert res[:errors].any?
    assert res[:errors].first[:subject] =~ /Unable to connect/
  end
  
  def test_no_url
    @plugin=ModPagespeedMonitoring.new(nil,{},{})
    res = @plugin.run()
    assert res[:errors].any?
    assert res[:errors].first[:subject] =~ /Please provide a url to mod_pagespeed_statistics/
  end  
end