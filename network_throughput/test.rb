require File.expand_path('../../test_helper.rb', __FILE__)
require File.expand_path('../network_throughput.rb', __FILE__)

class NetworkThroughputTest < Test::Unit::TestCase
  
  def test_initial_run
    IO.expects(:readlines).with('/proc/net/dev').returns(YAML.load(File.read(File.dirname(__FILE__)+'/fixtures/normal.yml'))).once
    @plugin=NetworkThroughput.new(nil,{},{})
    res = @plugin.run()
    assert_equal 8, res[:memory].size
    res[:memory].keys.each do |k|
      assert k =~ /eth1|eth0/
    end
    assert res[:errors].empty?
  end
  
  def test_initial_run_without_default_regex_match
    IO.expects(:readlines).with('/proc/net/dev').returns(YAML.load(File.read(File.dirname(__FILE__)+'/fixtures/no_eth1_or_eth0.yml'))).once
    @plugin=NetworkThroughput.new(nil,{},{})
    res = @plugin.run()
    assert_equal "No interfaces found", res[:errors].first[:subject]
  end
  
  def test_initial_run_with_provided_interfaces
    IO.expects(:readlines).with('/proc/net/dev').returns(YAML.load(File.read(File.dirname(__FILE__)+'/fixtures/no_eth1_or_eth0.yml'))).once
    @plugin=NetworkThroughput.new(nil,{},{"interfaces" => 'em|vnet'})
    res = @plugin.run()
    assert_equal 12, res[:memory].size
    res[:memory].keys.each do |k|
      assert k =~ /em|vnet/
    end
    assert res[:errors].empty?
  end

end 