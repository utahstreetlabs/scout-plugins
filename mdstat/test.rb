require File.expand_path('../../test_helper.rb', __FILE__)
require File.expand_path('../mdstat.rb', __FILE__)

class MdStatTest < Test::Unit::TestCase
    def test_success      
      plugin=MdStat.new(nil,{},{})
      plugin.stubs(:`).with("cat /proc/mdstat").returns(File.read(File.dirname(__FILE__)+'/fixtures/proc_mdstat_raid5.txt'))

      res = plugin.run()
      assert res[:errors].empty?
      assert res[:memory][:mdstat_ok]
      assert res[:reports].any?       
    end # test_success  
    
    def test_error_with_raid_0
      plugin=MdStat.new(nil,{},{})
      plugin.stubs(:`).with("cat /proc/mdstat").returns(File.read(File.dirname(__FILE__)+'/fixtures/proc_mdstat_raid0.txt'))

      res = plugin.run()
      assert res[:errors].any?
    end
end