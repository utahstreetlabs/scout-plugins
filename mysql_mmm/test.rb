require File.expand_path('../../test_helper.rb', __FILE__)
require File.expand_path('../mysql_mmm.rb', __FILE__)


class MySQLMMMTest < Test::Unit::TestCase
  
  def setup
    @options=parse_defaults("mysql_mmm")
  end
  
  # TODO
  def test_success
    @plugin=MySQLMMM.new(nil,{},{})
    #@plugin.expects(:`).with("sudo mmm_control show").returns(SHOW).once
    #res = @plugin.run()
    assert true
  end
 
end