require File.expand_path('../../test_helper.rb', __FILE__)
require File.expand_path('../apache_load.rb', __FILE__)

class ApacheLoadTest < Test::Unit::TestCase
  
  def setup
    @options=parse_defaults("apache_load")
  end
  
  def teardown
    FakeWeb.clean_registry
  end
  
  def test_run
    time = Time.parse("12/1/12 12:00")
    Timecop.travel(time) do 
      plugin=ApacheLoad.new(nil,{},@options)
      FakeWeb.register_uri(:get, 'http://localhost/server-status?auto', :body => File.read(File.dirname(__FILE__)+'/fixtures/initial.txt'))

      res= plugin.run()

      assert res[:alerts].empty?, res[:alerts]
      assert res[:errors].empty?, res[:errors]
      assert_equal 49, res[:reports].first[:idle_workers]
      assert_equal 1, res[:reports].first[:busy_workers]
      memory=res[:memory]
      assert memory.any?
      
      Timecop.travel(time+60) do
        plugin=ApacheLoad.new(nil,memory,@options)
        FakeWeb.register_uri(:get, 'http://localhost/server-status?auto', :body => File.read(File.dirname(__FILE__)+'/fixtures/second_run.txt'))
        res= plugin.run()
        assert_in_delta 10/60.to_f, res[:reports].first[:current_load], 0.001
      end
    end  
  end
  
end