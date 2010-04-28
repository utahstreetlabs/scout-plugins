require File.dirname(__FILE__)+"/../test_helper"
require File.dirname(__FILE__)+"/rails_requests"

class RailsRequestsTest < Test::Unit::TestCase

  def setup
    @options=parse_defaults("rails_requests")
    @log = File.dirname(__FILE__)+"/production_rails_2_3.log"
  end

  def test_run
    plugin=RailsRequests.new(nil,{:last_request_time=>Time.parse("2010-04-26 00:00:00")},@options.merge(:log => @log))
    res=plugin.run    
    assert_equal 0.0, res[:reports].first[:slow_requests_percentage]
    assert_equal "0.36", res[:reports].first[:average_request_length]
    assert_equal 1, res[:summaries].size
  end

  def test_run_with_slow_requests
    plugin=RailsRequests.new(nil,{:last_request_time=>Time.parse("2010-04-26 00:00:00")},@options.merge(:log => @log, :max_request_length=>2))
    res=plugin.run
    assert_equal 10, res[:reports].first[:slow_requests_percentage]
    assert_equal 1, res[:alerts].size
    assert_equal "Maximum Time(2 sec) exceeded on 1 request",res[:alerts].first[:subject] 
  end

  def test_run_with_two_slow_requests
    plugin=RailsRequests.new(nil,{:last_request_time=>Time.parse("2010-04-26 00:00:00")},@options.merge(:log => @log, :max_request_length=>1))
    res=plugin.run
    assert_equal 20, res[:reports].first[:slow_requests_percentage]
    assert_equal 1, res[:alerts].size
    assert_equal "Maximum Time(1 sec) exceeded on 2 requests",res[:alerts].first[:subject]
  end
  
end