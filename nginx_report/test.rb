require File.expand_path('../../test_helper.rb', __FILE__)
require File.expand_path('../nginx_report.rb', __FILE__)

require 'open-uri'
class NginxReportTest < Test::Unit::TestCase
  def setup

  end
  
  def teardown
    FakeWeb.clean_registry    
  end
  
  def test_initial_run
    uri="http://127.0.0.1/nginx_status"
    FakeWeb.register_uri(:get, uri, 
      [
       {:body => File.read(File.dirname(__FILE__)+'/fixtures/nginx_status.txt')},
       {:body => nil}
      ]
    )
    
    @plugin = NginxReport.new(nil,{},{})
    @res = @plugin.run
    pp @res
  end
end