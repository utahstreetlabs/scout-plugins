require File.expand_path('../../test_helper.rb', __FILE__)
require File.expand_path('../mysql_slow_queries.rb', __FILE__)


class RailsRequestsTest < Test::Unit::TestCase

  def setup
    @options=parse_defaults("mysql_slow_queries")
    @log = File.dirname(__FILE__)+"/log/default.log"
    @ey_log = File.dirname(__FILE__)+"/log/engine_yard.log"
  end
  
  def test_default_parsing
    # Time: 101201 12:00:00
    plugin=ScoutMysqlSlow.new(nil,{},@options.merge(:mysql_slow_log => @log))
    time = Time.parse("101201 12:00:00") - 60
    Timecop.travel(time) do
      res=plugin.run
      assert_equal 1, res[:alerts].size
      assert_equal 60.0, res[:reports].first[:slow_queries]
      assert_equal Time.parse("101201 12:00:00"), res[:memory][:last_run_entry_timestamp]
    end
  end
  
  def test_engine_yard_parsing
    plugin=ScoutMysqlSlow.new(nil,{},@options.merge(:mysql_slow_log => @ey_log))
    time = Time.parse("101201 12:00:00") - 60
    Timecop.travel(time) do
      res=plugin.run
      assert_equal 1, res[:alerts].size
      assert_equal 60.0, res[:reports].first[:slow_queries]
      assert_equal Time.parse("101201 12:00:00"), res[:memory][:last_run_entry_timestamp]
    end
  end
  
  def test_no_file_path
    plugin=ScoutMysqlSlow.new(nil,{},@options)
    res=plugin.run
    assert_equal 1, res[:errors].size
    assert res[:reports].empty?
  end
  
  def test_bad_file_path
    plugin=ScoutMysqlSlow.new(nil,{},@options.merge(:mysql_slow_log => 'bad'))
    res=plugin.run
    assert_equal 1, res[:errors].size
    assert res[:reports].empty?
  end
  
end