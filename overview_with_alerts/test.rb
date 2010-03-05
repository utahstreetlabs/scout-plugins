require File.dirname(__FILE__)+"/../test_helper"
require File.dirname(__FILE__)+"/overview_with_alerts"

class OverviewWithAlertsTest < Test::Unit::TestCase

  def setup
    @options=parse_defaults("overview_with_alerts")
  end

  def teardown
  end

  def test_clean_run
    # Stub the plugin instance where necessary and run
    # @plugin=PluginName.new(last_run, memory, options)
    #                        date      hash    hash
    @plugin=OverviewWithAlerts.new(nil,{},@options)
    @plugin.stubs(:shell).with("df -h").returns(FIXTURES[:df]).once
    @plugin.stubs(:shell).with("cat /proc/meminfo").returns(FIXTURES[:meminfo]).once
    @plugin.stubs(:shell).with("uptime").returns(FIXTURES[:uptime]).once
    res= @plugin.run()

    # assertions
    assert res[:alerts].empty?
    assert res[:errors].empty?
    assert_equal 1,  res[:reports].size
  end

  def test_memory_alert
    @plugin=OverviewWithAlerts.new(nil,{},@options)
    @plugin.stubs(:shell).with("df -h").returns(FIXTURES[:df]).once
    @plugin.stubs(:shell).with("cat /proc/meminfo").returns(FIXTURES[:meminfo_alert]).once
    @plugin.stubs(:shell).with("uptime").returns(FIXTURES[:uptime]).once
    res= @plugin.run()
    assert_equal 1, res[:alerts].size
    assert_equal "Memory Usage Alert", res[:alerts].first[:subject]

    @memory=res[:memory] # to be used in tests that run this as a precursor
  end

  def test_memory_alert_repeats
    test_memory_alert
    last_run=Time.now
    Timecop.travel(Time.now+60*40) do # forty minutes in future
      @plugin=OverviewWithAlerts.new(last_run,@memory,@options)
      @plugin.stubs(:shell).with("df -h").returns(FIXTURES[:df]).once
      @plugin.stubs(:shell).with("cat /proc/meminfo").returns(FIXTURES[:meminfo_alert]).once
      @plugin.stubs(:shell).with("uptime").returns(FIXTURES[:uptime]).once
      res = @plugin.run()
      assert_equal 1, res[:alerts].size
      assert res[:alerts].first[:body].include?("Duration")
    end
  end

  def test_memory_alert_does_not_repeat_too_soon
    test_memory_alert
    last_run=Time.now
    Timecop.travel(Time.now+60*5) do # five minutes in future
      @plugin=OverviewWithAlerts.new(last_run,@memory,@options)
      @plugin.stubs(:shell).with("df -h").returns(FIXTURES[:df]).once
      @plugin.stubs(:shell).with("cat /proc/meminfo").returns(FIXTURES[:meminfo_alert]).once
      @plugin.stubs(:shell).with("uptime").returns(FIXTURES[:uptime]).once
      res= @plugin.run()
      assert_equal 0, res[:alerts].size
    end
  end

  def test_memory_back_to_normal
    test_memory_alert
    last_run=Time.now
    Timecop.travel(Time.now+60*5) do # five minutes in future
      @plugin=OverviewWithAlerts.new(last_run,@memory,@options)
      @plugin.stubs(:shell).with("df -h").returns(FIXTURES[:df]).once
      @plugin.stubs(:shell).with("cat /proc/meminfo").returns(FIXTURES[:meminfo]).once
      @plugin.stubs(:shell).with("uptime").returns(FIXTURES[:uptime]).once
      res= @plugin.run()
      assert_equal 1, res[:alerts].size
      assert_equal "Memory Usage OK", res[:alerts].first[:subject]
    end
  end

  def test_disk_alert
    @plugin=OverviewWithAlerts.new(nil,{},@options)
    @plugin.stubs(:shell).with("df -h").returns(FIXTURES[:df_alert]).once
    @plugin.stubs(:shell).with("cat /proc/meminfo").returns(FIXTURES[:meminfo]).once
    @plugin.stubs(:shell).with("uptime").returns(FIXTURES[:uptime]).once
    res= @plugin.run()
    assert_equal 1, res[:alerts].size
    assert_equal "Disk Usage Alert", res[:alerts].first[:subject]

    @memory=res[:memory] # to be used in tests that run this as a precursor
  end

  def test_disk_alert_repeats
    test_disk_alert
    last_run=Time.now
    Timecop.travel(Time.now+60*40) do # forty minutes in future
      @plugin=OverviewWithAlerts.new(last_run,@memory,@options)
      @plugin.stubs(:shell).with("df -h").returns(FIXTURES[:df_alert]).once
      @plugin.stubs(:shell).with("cat /proc/meminfo").returns(FIXTURES[:meminfo]).once
      @plugin.stubs(:shell).with("uptime").returns(FIXTURES[:uptime]).once
      res = @plugin.run()
      assert_equal 1, res[:alerts].size
      assert res[:alerts].first[:body].include?("Duration")
    end
  end

  def test_disk_alert_does_not_repeat_too_soon
    test_disk_alert
    last_run=Time.now
    Timecop.travel(Time.now+60*5) do # five minutes in future
      @plugin=OverviewWithAlerts.new(last_run,@memory,@options)
      @plugin.stubs(:shell).with("df -h").returns(FIXTURES[:df_alert]).once
      @plugin.stubs(:shell).with("cat /proc/meminfo").returns(FIXTURES[:meminfo]).once
      @plugin.stubs(:shell).with("uptime").returns(FIXTURES[:uptime]).once
      res= @plugin.run()
      assert_equal 0, res[:alerts].size
    end
  end

  def test_disk_back_to_normal
    test_disk_alert
    last_run=Time.now
    Timecop.travel(Time.now+60*5) do # five minutes in future
      @plugin=OverviewWithAlerts.new(last_run,@memory,@options)
      @plugin.stubs(:shell).with("df -h").returns(FIXTURES[:df]).once
      @plugin.stubs(:shell).with("cat /proc/meminfo").returns(FIXTURES[:meminfo]).once
      @plugin.stubs(:shell).with("uptime").returns(FIXTURES[:uptime]).once
      res= @plugin.run()
      assert_equal 1, res[:alerts].size
      assert_equal "Disk Usage OK", res[:alerts].first[:subject]
    end
  end


  FIXTURES=YAML.load(<<-EOS)
    :meminfo: |
      MemTotal:      1048796 kB
      MemFree:        220928 kB
      Buffers:        105780 kB
      Cached:         291456 kB
      SwapCached:      43864 kB
      Active:         422088 kB
      Inactive:       304300 kB
      SwapTotal:     2097144 kB
      SwapFree:      2029200 kB
      Dirty:             148 kB
      Writeback:           0 kB
      AnonPages:      328480 kB
      Mapped:          13732 kB
      Slab:            59796 kB
      SReclaimable:     9748 kB
      SUnreclaim:      50048 kB
      PageTables:       5244 kB
      NFS_Unstable:        0 kB
      Bounce:              0 kB
      CommitLimit:   2621540 kB
      Committed_AS:  1209676 kB
      VmallocTotal: 34359738367 kB
      VmallocUsed:      1220 kB
      VmallocChunk: 34359737147 kB
    :meminfo_alert: |
      MemTotal:       708796 kB
      MemFree:          2000 kB
      Buffers:             0 kB
      Cached:              0 kB
      SwapCached:      43864 kB
      Active:         422088 kB
      Inactive:       304300 kB
      SwapTotal:           0 kB
      SwapFree:            0 kB
      Dirty:             148 kB
      Writeback:           0 kB
      AnonPages:      328480 kB
      Mapped:          13732 kB
      Slab:            59796 kB
      SReclaimable:     9748 kB
      SUnreclaim:      50048 kB
      PageTables:       5244 kB
      NFS_Unstable:        0 kB
      Bounce:              0 kB
      CommitLimit:   2621540 kB
      Committed_AS:  1209676 kB
      VmallocTotal: 34359738367 kB
      VmallocUsed:      1220 kB
      VmallocChunk: 34359737147 kB
    :df: |
      Filesystem            Size  Used Avail Use% Mounted on
      /dev/sda1              38G   14G   22G  39% /
      varrun                513M   48K  513M   1% /var/run
      varlock               513M     0  513M   0% /var/lock
      udev                  513M   16K  513M   1% /dev
      devshm                513M     0  513M   0% /dev/shm
    :df_alert: |
      Filesystem            Size  Used Avail Use% Mounted on
      /dev/sda1              38G   34G    4G  90% /
      varrun                513M   48K  513M   1% /var/run
      varlock               513M     0  513M   0% /var/lock
      udev                  513M   16K  513M   1% /dev
      devshm                513M     0  513M   0% /dev/shm
    :uptime: |
      15:36  up 33 days,  3:29, 4 users, load averages: 1.77 0.90 0.64
  EOS

end