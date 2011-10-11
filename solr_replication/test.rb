require File.expand_path('../../test_helper.rb', __FILE__)
require File.expand_path('../solr_replication.rb', __FILE__)

require 'open-uri'
class SolrReplicationTest < Test::Unit::TestCase

  def teardown
    FakeWeb.clean_registry
  end

  def test_should_report
    master='http://192.168.0.1:8983'
    slave='http://localhost:8765'
    rep_path='/solr/admin/replication/index.html'
    FakeWeb.register_uri(:get, master+rep_path, :body => File.read(File.dirname(__FILE__)+'/fixtures/sample.html'))
    FakeWeb.register_uri(:get, slave+rep_path, :body => File.read(File.dirname(__FILE__)+'/fixtures/sample.html'))
    
    @plugin=SolrReplication.new(nil,{},{:master => master, :slave => slave, :replication_path => rep_path})
    res = @plugin.run()
    assert res[:errors].empty?
    assert_equal 0, res[:reports].first["delay"]
  end
  
  def test_should_error_with_invalid_master
    slave='http://localhost:8765'
    rep_path='/solr/admin/replication/index.html'
    FakeWeb.register_uri(:get, slave+rep_path, :body => File.read(File.dirname(__FILE__)+'/fixtures/sample.html'))
    @plugin=SolrReplication.new(nil,{},{:master => 'http://fake', :slave => slave, :replication_path => rep_path})
    res = @plugin.run()
    assert_equal 1, res[:errors].size
  end
end