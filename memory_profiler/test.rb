require File.expand_path('../../test_helper.rb', __FILE__)
require File.expand_path('../memory_profiler.rb', __FILE__)

class MemoryProfilerTest < Test::Unit::TestCase
    # Stub the plugin instance where necessary and run
    # @plugin=PluginName.new(last_run, memory, options)
    #                        date      hash    hash
    def test_success_linux
      @plugin=MemoryProfiler.new(nil,{},{})
      @plugin.stubs(:`).with("cat /proc/meminfo").returns(File.read(File.dirname(__FILE__)+'/fixtures/proc_meminfo.txt'))
      @plugin.stubs(:`).with("uname").returns('Linux')

      res = @plugin.run()
      
      assert res[:errors].empty?
      assert !res[:memory][:solaris]
      assert_equal 7, res[:reports].first.keys.size
      
      r = res[:reports].first
      assert_equal 0, r["Swap Used"]
      assert_equal 255, r["Swap Total"]
      assert_equal 25, r["% Memory Used"]
      assert_equal 0, r["% Swap Used"]
      assert_equal 264, r["Memory Used"]
      assert_equal 1024, r["Memory Total"]
      assert_equal 760, r["Memory Available"]
    end
    
    def test_success_linux_second_run
      # shouldn't run uname again as it is stored in memory
      @plugin=MemoryProfiler.new(Time.now-60*10,{:solaris=>false,:darwin=>false},{})
      @plugin.stubs(:`).with("cat /proc/meminfo").returns(File.read(File.dirname(__FILE__)+'/fixtures/proc_meminfo.txt'))

      res = @plugin.run()
      assert_equal false,res[:memory][:solaris]
    end
    
    def test_success_with_no_buffers
      @plugin=MemoryProfiler.new(nil,{},{})
      @plugin.stubs(:`).with("cat /proc/meminfo").returns(File.read(File.dirname(__FILE__)+'/fixtures/no_buffers.txt'))
      @plugin.stubs(:`).with("uname").returns('Linux')

      res = @plugin.run()
      
      assert res[:errors].empty?
      assert !res[:memory][:solaris]
      assert_equal 6, res[:reports].first.keys.size
    end
    
    def test_success_solaris
      @plugin=MemoryProfiler.new(nil,{},{})
      @plugin.stubs(:`).with("prstat -c -Z 1 1").returns(File.read(File.dirname(__FILE__)+'/fixtures/prstat.txt'))
      @plugin.stubs(:`).with("/usr/sbin/prtconf | grep Memory").returns(File.read(File.dirname(__FILE__)+'/fixtures/prtconf.txt'))
      @plugin.stubs(:`).with("swap -s").returns(File.read(File.dirname(__FILE__)+'/fixtures/swap.txt'))
      @plugin.stubs(:`).with("uname").returns('SunOS')

      res = @plugin.run()
      
      assert res[:errors].empty?
      assert res[:memory][:solaris]
      
      assert_equal 6, res[:reports].first.keys.size

      r = res[:reports].first
      assert_equal 1388, r["Swap Used"]
      assert_equal 2124.1, r["Swap Total"]
      assert_equal (1388/2124.to_f*100).to_i, r["% Swap Used"]
      assert_equal 2, r["% Memory Used"]
      assert_equal 872, r["Memory Used"]
      assert_equal 32763, r["Memory Total"]
    end
    
    def test_success_solaris_second_run
      @plugin=MemoryProfiler.new(Time.now-60*10,{:solaris=>true},{})
      @plugin.stubs(:`).with("prstat -c -Z 1 1").returns(File.read(File.dirname(__FILE__)+'/fixtures/prstat.txt'))
      @plugin.stubs(:`).with("/usr/sbin/prtconf | grep Memory").returns(File.read(File.dirname(__FILE__)+'/fixtures/prtconf.txt'))
      @plugin.stubs(:`).with("swap -s").returns(File.read(File.dirname(__FILE__)+'/fixtures/swap.txt'))
      @plugin.stubs(:`).with("uname").returns('SunOS').never

      res = @plugin.run()
      assert_equal true,res[:memory][:solaris]
    end
    
    def test_success_solaris_with_gb_swap_units
      @plugin=MemoryProfiler.new(nil,{},{})
      @plugin.stubs(:`).with("prstat -c -Z 1 1").returns(File.read(File.dirname(__FILE__)+'/fixtures/prstat.txt'))
      @plugin.stubs(:`).with("/usr/sbin/prtconf | grep Memory").returns(File.read(File.dirname(__FILE__)+'/fixtures/prtconf.txt'))
      @plugin.stubs(:`).with("swap -s").returns(File.read(File.dirname(__FILE__)+'/fixtures/swap_gb.txt'))
      @plugin.stubs(:`).with("uname").returns('SunOS')

      res = @plugin.run()
      
      assert res[:errors].empty?
      assert res[:memory][:solaris]
      
      r = res[:reports].first      
      assert_equal 6, r.keys.size

      assert_equal 1388, r["Swap Used"]
      assert_equal 86016, r["Swap Total"]
      assert_equal (1388/86016.to_f*100).to_i, r["% Swap Used"]
      assert_equal 2, r["% Memory Used"]
      assert_equal 872, r["Memory Used"]
      assert_equal 32763, r["Memory Total"]
    end
    
    def test_success_darwin
      @plugin=MemoryProfiler.new(nil,{},{})
      @plugin.stubs(:`).with("top -l1 -n0 -u").returns(File.read(File.dirname(__FILE__)+'/fixtures/top_darwin.txt'))
      @plugin.stubs(:`).with("uname").returns('Darwin')

      res = @plugin.run()
      
      assert res[:errors].empty?
      assert !res[:memory][:solaris]
      assert res[:memory][:darwin]
      
      assert_equal 4, res[:reports].first.keys.size
      
      r = res[:reports].first
      assert_equal 77, r["% Memory Used"]
      assert_equal 3158, r["Memory Used"]
      assert_equal 4094, r["Memory Total"]
      assert_equal 936, r["Memory Available"]
    end
    
    def test_success_darwin_second_run
      @plugin=MemoryProfiler.new(Time.now-60*10,{:solaris=>false,:darwin=>true},{})
      @plugin.stubs(:`).with("top -l1 -n0 -u").returns(File.read(File.dirname(__FILE__)+'/fixtures/top_darwin.txt'))
      @plugin.stubs(:`).with("uname").returns('Darwin')

      res = @plugin.run()
      
      assert res[:errors].empty?
      assert !res[:memory][:solaris]
      assert res[:memory][:darwin]
      
      assert_equal 4, res[:reports].first.keys.size
      
      r = res[:reports].first
      assert_equal 77, r["% Memory Used"]
    end
end