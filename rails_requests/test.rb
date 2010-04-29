require File.dirname(__FILE__)+"/../test_helper"
require File.dirname(__FILE__)+"/rails_requests"

class RailsRequestsTest < Test::Unit::TestCase

  def setup
    @options=parse_defaults("rails_requests")
    @log = File.dirname(__FILE__)+"/log/production_rails_2_3.log"
    @rails3_log = File.dirname(__FILE__)+"/log/production_rails_3b3.log"
  end

  def test_run_rails_2_3
    plugin=RailsRequests.new(nil,{:last_request_time=>Time.parse("2010-04-26 00:00:00")},@options.merge(:log => @log))
    res=plugin.run
    assert_equal 0.0, res[:reports].first[:slow_requests_percentage]
    assert_equal "0.36", res[:reports].first[:average_request_length]
    assert_equal 1, res[:summaries].size
  end

  def test_run_with_slow_request_rails_2_3
    plugin=RailsRequests.new(nil,{:last_request_time=>Time.parse("2010-04-26 00:00:00")},@options.merge(:log => @log, :max_request_length=>2))
    res=plugin.run
    assert_equal 10, res[:reports].first[:slow_requests_percentage]
    assert_equal 1, res[:alerts].size
    assert_equal "Maximum Time(2 sec) exceeded on 1 request",res[:alerts].first[:subject]
    assert_match %r(http://hotspotr.com/wifi/map/660-vancouver-canada), res[:alerts].first[:body] 
  end

  def test_ignored_slow_request_rails_2_3
    plugin=RailsRequests.new(nil,{:last_request_time=>Time.parse("2010-04-26 00:00:00")},@options.merge(:log => @log, :max_request_length=>2, :ignored_actions=>'map'))
    res=plugin.run
    assert_equal 0, res[:reports].first[:slow_requests_percentage]
    assert_equal 0, res[:alerts].size
  end

  def test_run_with_two_slow_requests_rails_2_3
    plugin=RailsRequests.new(nil,{:last_request_time=>Time.parse("2010-04-26 00:00:00")},@options.merge(:log => @log, :max_request_length=>1))
    res=plugin.run
    assert_equal 20, res[:reports].first[:slow_requests_percentage]
    assert_equal 1, res[:alerts].size
    assert_equal "Maximum Time(1 sec) exceeded on 2 requests", res[:alerts].first[:subject]
    assert_equal "http://hotspotr.com/wifi/map/660-vancouver-canada\n\nhttp://hotspotr.com/wifi\n\n", res[:alerts].first[:body]
  end

  def test_run_rails_3
    plugin=RailsRequests.new(nil,{:last_request_time=>Time.parse("2010-04-26 00:00:00")},@options.merge(:log => @rails3_log))
    res=plugin.run
    assert_not_nil res[:reports].first[:average_request_length]
  end

  def test_run_with_slow_request_rails_3
    plugin=RailsRequests.new(nil,{:last_request_time=>Time.parse("2010-04-26 00:00:00")},@options.merge(:log => @rails3_log, :max_request_length=>2))
    res=plugin.run
    assert_equal 10, res[:reports].first[:slow_requests_percentage]
    assert_equal 1, res[:alerts].size
    assert_equal "Maximum Time(2 sec) exceeded on 1 request",res[:alerts].first[:subject]
    assert_match %r(/home), res[:alerts].first[:body]
  end

  def test_ignored_slow_request_rails_3
    plugin=RailsRequests.new(nil,{:last_request_time=>Time.parse("2010-04-26 00:00:00")},@options.merge(:log => @rails3_log, :max_request_length=>2, :ignored_actions=>'home'))
    res=plugin.run
    assert_equal 0, res[:reports].first[:slow_requests_percentage]
    assert_equal 0, res[:alerts].size
  end

  def test_wrong_log_path
    plugin=RailsRequests.new(nil,{:last_request_time=>Time.parse("2010-04-26 00:00:00")},@options.merge(:log => "BOGUS"))
    res=plugin.run
    assert_equal 1, res[:errors].size
    assert_match /Unable to find the Rails log file/, res[:errors].first[:subject]
  end

  def test_empty_log_file
    plugin=RailsRequests.new(nil,{:last_request_time=>Time.parse("2010-04-26 00:00:00")},
                             @options.merge(:log =>  File.dirname(__FILE__)+"/log/empty.log"))
    res=plugin.run
    assert_equal 1, res[:errors].size
    assert_match /Unknown Rails log format/, res[:errors].first[:subject]
  end



end