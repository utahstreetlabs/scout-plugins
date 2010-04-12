require File.dirname(__FILE__)+"/../test_helper"
require File.dirname(__FILE__)+"/apache_analyzer"

class ApacheAnalyzerTest < Test::Unit::TestCase

  def setup
    @options=parse_defaults("overview_with_alerts")
    @last_request_time = "11/Apr/2010 #{17+Time.now.utc_offset/60/60}:22:04" # applies UTC offset
    @duration_format = '%h %l %u %t "%r" %>s %b %D'
    @utc_log = File.dirname(__FILE__)+"/utc.log"
  end
  
  def test_initial_run_with_utc
    # last time in log file (in UTC)
    time = Time.parse(@last_request_time) 
    Timecop.travel(time) do 
      plugin=ApacheAnalyzer.new(nil,{},{:log => @utc_log, :format => @duration_format})
      res = plugin.run()
      assert_equal 68, res[:reports].first[:lines_scanned]
      # note - this is stored in the timezone of this server
      assert_equal Time.parse("Sun Apr 11 17:22:04 -0700 2010"), res[:memory][:last_request_time]
    end
  end
  
  def test_later_run_with_utc
    # last time in log file (in UTC)
    time = Time.parse(@last_request_time) 
    # pretend a run a couple of minutes earlier
    memory = {:last_request_time => Time.parse("Sun Apr 11 17:20:19 -0700 2010")}
    memory[:last_summary_time] = memory[:last_request_time]
    Timecop.travel(time) do 
      plugin=ApacheAnalyzer.new(time,memory,{:log => @utc_log, :format => @duration_format})
      res = plugin.run()
      assert_equal 21, res[:reports].first[:lines_scanned]
      # note - this is stored in the timezone of this server
      assert_equal Time.parse("Sun Apr 11 17:22:04 -0700 2010"), res[:memory][:last_request_time]
    end
  end
  
end