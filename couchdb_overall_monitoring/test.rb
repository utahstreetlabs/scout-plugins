require File.expand_path('../../test_helper.rb', __FILE__)
require File.expand_path('../couchdb_overall_monitoring.rb', __FILE__)

require 'open-uri'
class CouchDBOverallMonitoringTest < Test::Unit::TestCase
  def setup
    setup_urls
  end
  
  def teardown
    FakeWeb.clean_registry    
  end
  
  def test_initial_run
    @plugin=CouchDBOverallMonitoring.new(nil,{},{:couchdb_host=>'http://127.0.0.1',:couchdb_port=>'5984'})
    res = @plugin.run()
    assert_equal res[:memory]["_counter_database_reads"][:value], 100
    assert_equal res[:memory]["_counter_database_writes"][:value], 1000    
  end
  
  def test_normal_run
    time = Time.now
    Timecop.travel(time-60*10) do
      @plugin=CouchDBOverallMonitoring.new(nil,{},{:couchdb_host=>'http://127.0.0.1',:couchdb_port=>'5984'})
      res = @plugin.run()
      first_run_memory = res[:memory]
      
      # now - 10 minutes later
      Timecop.travel(time) do
        @plugin=CouchDBOverallMonitoring.new(nil,first_run_memory,{:couchdb_host=>'http://127.0.0.1',:couchdb_port=>'5984'})
        res = @plugin.run()
        reports = res[:reports]     
        assert_in_delta 10/(10*60).to_f, reports.first['database_reads'], 0.001
        assert_in_delta 1000/(10*60).to_f, reports[1]['database_writes'], 0.001
      end
    end # Timecop.travel
  end
  
  def test_not_found
    CouchDBOverallMonitoring::METRICS.each do |metric|
      uri="http://127.0.0.1:5984/_stats/couchdb/#{metric}"
      FakeWeb.register_uri(:get, uri, :status => ["404", "Not Found"])
    end
    
    @plugin=CouchDBOverallMonitoring.new(nil,{},{:couchdb_host=>'http://127.0.0.1',:couchdb_port=>'5984'})
    res = @plugin.run()
    assert res[:errors].any?
  end
  
  def test_bad_hostname
    @plugin=CouchDBOverallMonitoring.new(nil,{},{:couchdb_host=>'http://fake',:couchdb_port=>'5984'})
    res = @plugin.run()
    assert res[:errors].any?
  end
  
  def test_no_host
    CouchDBOverallMonitoring::METRICS.each do |metric|
      uri="http://127.0.0.1:5984/_stats/couchdb/#{metric}"
      FakeWeb.register_uri(:get, uri, :body => FIXTURES[(metric+'_initial').to_sym])
    end
    
    @plugin=CouchDBOverallMonitoring.new(nil,{},{:couchdb_host=>nil,:couchdb_port=>'5984'})
    res = @plugin.run()
    assert res[:errors].any?
  end
  
  def test_no_port
    CouchDBOverallMonitoring::METRICS.each do |metric|
      uri="http://127.0.0.1:5984/_stats/couchdb/#{metric}"
      FakeWeb.register_uri(:get, uri, :body => FIXTURES[(metric+'_initial').to_sym])
    end
    
    @plugin=CouchDBOverallMonitoring.new(nil,{},{:couchdb_host=>'http://127.0.0.1',:couchdb_port=>nil})
    res = @plugin.run()
    assert res[:errors].any?
  end
  
  ###############
  ### Helpers ###
  ###############
  
  def setup_urls
    CouchDBOverallMonitoring::METRICS.each do |metric|
      uri="http://127.0.0.1:5984/_stats/couchdb/#{metric}"
      FakeWeb.register_uri(:get, uri, 
        [
         {:body => FIXTURES[(metric+'_initial').to_sym]},
         {:body => FIXTURES[(metric+'_second_run').to_sym]}
        ]
      )
    end
    CouchDBOverallMonitoring::HTTP_REQUEST_METHODS.each do |method|
      uri="http://127.0.0.1:5984/_stats/httpd_request_methods/#{method}"
      FakeWeb.register_uri(:get, uri, :body => FIXTURES["httpd_methods_#{method.downcase}".to_sym])
    end    
    CouchDBOverallMonitoring::HTTP_STATS.each do |metric|
      uri="http://127.0.0.1:5984/_stats/httpd_request_methods/#{metric}"
      FakeWeb.register_uri(:get, uri, :body => FIXTURES["httpd_stats_#{metric}".to_sym])
    end
  end
  
  
  ################
  ### Fixtures ###
  ################
  
  FIXTURES=YAML.load(<<-EOS)
    :database_reads_initial: |
      {
        "couchdb":{
          "database_reads":{
            "current":100,
            "count":88024,
            "mean":46.73568572207625,
            "min":0,
            "max":870,
            "stddev":96.394365139495,
            "description":"number of times a document was read from a database"
          }
        }
      }
    :database_writes_initial: |
      {
        "couchdb":{
          "database_writes":{
            "current":1000,
            "count":88024,
            "mean":46.73568572207625,
            "min":0,
            "max":870,
            "stddev":96.394365139495,
            "description":""
          }
        }
      }
    :database_reads_second_run: |
      {
        "couchdb":{
          "database_reads":{
            "current":110,
            "count":88024,
            "mean":46.73568572207625,
            "min":0,
            "max":870,
            "stddev":96.394365139495,
            "description":"number of times a document was read from a database"
          }
        }
      }
    :database_writes_second_run: |
      {
        "couchdb":{
          "database_writes":{
            "current":2000,
            "count":88024,
            "mean":46.73568572207625,
            "min":0,
            "max":870,
            "stddev":96.394365139495,
            "description":""
          }
        }
      }
    :httpd_methods_get: |   
      {
        "httpd_request_methods": {
          "GET": {
            "current": 2,
            "max": 1,
            "mean": 0.00096946194861852,
            "description": "number of HTTP GET requests",
            "stddev": 0.0311210875797858,
            "min": 0,
            "count": 2063
          }
        }
      }
    :httpd_methods_post: |   
      {
        "httpd_request_methods": {
          "POST": {
            "current": 2,
            "max": 1,
            "mean": 0.00096946194861852,
            "description": "number of HTTP GET requests",
            "stddev": 0.0311210875797858,
            "min": 0,
            "count": 2063
          }
        }
      }
    :httpd_methods_put: |   
      {
        "httpd_request_methods": {
          "PUT": {
            "current": 2,
            "max": 1,
            "mean": 0.00096946194861852,
            "description": "number of HTTP GET requests",
            "stddev": 0.0311210875797858,
            "min": 0,
            "count": 2063
          }
        }
      }
    :httpd_methods_delete: |   
      {
        "httpd_request_methods": {
          "DELETE": {
            "current": 2,
            "max": 1,
            "mean": 0.00096946194861852,
            "description": "number of HTTP GET requests",
            "stddev": 0.0311210875797858,
            "min": 0,
            "count": 2063
          }
        }
      }
    :httpd_stats_requests: |
      {
        "httpd": {
          "requests": {
            "current": 2,
            "max": 1,
            "mean": 0.00096946194861852,
            "description": "number of HTTP requests",
            "stddev": 0.0311210875797858,
            "min": 0,
            "count": 2063
          }
        }
      }
    :httpd_stats_view_reads: |
      {
        "httpd": {
          "view_reads": {
            "current": 2,
            "max": 1,
            "mean": 0.00096946194861852,
            "description": "",
            "stddev": 0.0311210875797858,
            "min": 0,
            "count": 2063
          }
        }
      }  
  EOS
end