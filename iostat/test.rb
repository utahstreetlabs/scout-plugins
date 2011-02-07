require File.expand_path('../../test_helper.rb', __FILE__)
require File.expand_path('../iostat.rb', __FILE__)

class IostatTest < Test::Unit::TestCase
    # Stub the plugin instance where necessary and run
    # @plugin=PluginName.new(last_run, memory, options)
    #                        date      hash    hash
  def test_success
    @plugin=Iostat.new(nil,{},{})
    IO.expects(:readlines).with('/proc/diskstats').returns(FIXTURES[:diskstats_1].split(/\n/)).once
    @plugin.expects(:`).with("mount").returns(FIXTURES[:mount]).once

    res = @plugin.run()
    assert res[:memory].is_a?(Hash), "Plugin memory should be a hash"
    assert_equal 7, res[:memory].keys.size, "Plugin memory has the wrong number of keys"
    assert_equal 0, res[:reports].size, "Plugin shouldn't return any results first run"
    assert_equal 52087575, res[:memory]['_counter_rkbps'][:value]

    Timecop.travel(Time.now+5*60) do # 5 minute later
      new_plugin=Iostat.new(nil,res[:memory],{})
      IO.expects(:readlines).with('/proc/diskstats').returns(FIXTURES[:diskstats_2].split(/\n/)).once
      new_plugin.expects(:`).with("mount").returns(FIXTURES[:mount]).once
      res = new_plugin.run()
      assert_equal 7, res[:reports].size
    end
  end
  
  def test_error_on_bad_device_name
    @plugin=Iostat.new(nil,{},{:device => 'bad'})
    IO.expects(:readlines).with('/proc/diskstats').returns(FIXTURES[:diskstats_1].split(/\n/)).once
    @plugin.expects(:`).with("mount").returns(FIXTURES[:mount]).once

    res = @plugin.run()
    assert res[:errors].any?
  end
  
  def test_lvm
    @plugin=Iostat.new(nil,{},{})
    IO.expects(:readlines).with('/proc/diskstats').returns(FIXTURES[:lvm_diskstats].split(/\n/)).once
    @plugin.expects(:`).with("mount").returns(FIXTURES[:lvm_mount]).once
    
    res = @plugin.run()
    assert_equal 348375058/2, res[:memory]['_counter_rkbps'][:value]
  end

  FIXTURES=YAML.load(<<-EOS)
    :mount: |
      /dev/xvda1 on / type ext3 (rw,errors=remount-ro)
      proc on /proc type proc (rw,noexec,nosuid,nodev)
      none on /sys type sysfs (rw,noexec,nosuid,nodev)
      none on /sys/fs/fuse/connections type fusectl (rw)
      none on /sys/kernel/debug type debugfs (rw)
      none on /sys/kernel/security type securityfs (rw)
      none on /dev type devtmpfs (rw,mode=0755)
      none on /dev/pts type devpts (rw,noexec,nosuid,gid=5,mode=0620)
      none on /dev/shm type tmpfs (rw,nosuid,nodev)
      none on /var/run type tmpfs (rw,nosuid,mode=0755)
      none on /var/lock type tmpfs (rw,noexec,nosuid,nodev)
      none on /lib/init/rw type tmpfs (rw,nosuid,mode=0755)
      none on /var/lib/images/debugfs type debugfs (rw,relatime)
    :diskstats_1: |
       202       0 xvda 2291392 15908 104175150 31433830 24833528 8910093 269954008 717602680 0 83774100 749022260
       202       1 xvda1 2241909 9075 103724634 30905340 24794783 8838778 269073520 714244880 0 83625720 745136060
       202       2 xvda2 2 0 4 40 0 0 0 0 0 40 40
       202       5 xvda5 49433 6833 450128 528000 38745 71315 880488 3357800 0 681180 3885710
       202      64 xvde 101 148 804 300 0 0 0 0 0 300 300
       202      65 xvde1 74 148 588 110 0 0 0 0 0 110 110
       202      80 xvdf 53 0 424 220 0 0 0 0 0 220 220
    :diskstats_2: |
       202       0 xvda 2291392 15908 104175150 31433830 24834163 8910233 269960208 717605720 0 83774580 749025300
       202       1 xvda1 2241909 9075 103724634 30905340 24795418 8838918 269079720 714247920 0 83626200 745139100
       202       2 xvda2 2 0 4 40 0 0 0 0 0 40 40
       202       5 xvda5 49433 6833 450128 528000 38745 71315 880488 3357800 0 681180 3885710
       202      64 xvde 101 148 804 300 0 0 0 0 0 300 300
       202      65 xvde1 74 148 588 110 0 0 0 0 0 110 110
       202      80 xvdf 53 0 424 220 0 0 0 0 0 220 220
    :lvm_mount: |
       /dev/mapper/VolGroup00-LogVol00 on / type ext3 (rw)
       proc on /proc type proc (rw)
       sysfs on /sys type sysfs (rw)
       devpts on /dev/pts type devpts (rw,gid=5,mode=620)
       /dev/sda1 on /boot type ext3 (rw)
       tmpfs on /dev/shm type tmpfs (rw)
       none on /proc/sys/fs/binfmt_misc type binfmt_misc (rw)
       sunrpc on /var/lib/nfs/rpc_pipefs type rpc_pipefs (rw)
       nfsd on /proc/fs/nfsd type nfsd (rw)
       10.0.0.13:/data/backup/deploy on /var/deploy type nfs (rw,addr=10.0.0.13)
       10.0.0.55:/var/gplum/data on /var/gplum/data type nfs (rw,addr=10.0.0.55)
       10.0.0.250:/mnt/storage/data/content on /var/web/resources/content type nfs (rw,addr=10.0.0.250)
       10.0.0.250:/mnt/storage/data/catalog/images on /var/web/resources/catalog/images type nfs (ro,addr=10.0.0.250)
    :lvm_diskstats: |
       1    0 ram0 0 0 0 0 0 0 0 0 0 0 0
       1    1 ram1 0 0 0 0 0 0 0 0 0 0 0
       1    2 ram2 0 0 0 0 0 0 0 0 0 0 0
       1    3 ram3 0 0 0 0 0 0 0 0 0 0 0
       1    4 ram4 0 0 0 0 0 0 0 0 0 0 0
       1    5 ram5 0 0 0 0 0 0 0 0 0 0 0
       1    6 ram6 0 0 0 0 0 0 0 0 0 0 0
       1    7 ram7 0 0 0 0 0 0 0 0 0 0 0
       1    8 ram8 0 0 0 0 0 0 0 0 0 0 0
       1    9 ram9 0 0 0 0 0 0 0 0 0 0 0
       1   10 ram10 0 0 0 0 0 0 0 0 0 0 0
       1   11 ram11 0 0 0 0 0 0 0 0 0 0 0
       1   12 ram12 0 0 0 0 0 0 0 0 0 0 0
       1   13 ram13 0 0 0 0 0 0 0 0 0 0 0
       1   14 ram14 0 0 0 0 0 0 0 0 0 0 0
       1   15 ram15 0 0 0 0 0 0 0 0 0 0 0
       8    0 sda 7208126 3808614 168784488 19934642 1688527 7078331 70145340 160148291 0 20557651 180090757
       8    1 sda1 1466 2942 22 44
       8    2 sda2 11015409 168781298 8768162 70145296
       8   16 sdb 6513079 3753679 180040600 14897122 1004097 3583889 36706008 198478565 0 16333337 213377206
       8   17 sdb1 10266727 180040352 4588251 36706008
       253    0 dm-0 21226312 0 348375058 44834474 13273319 0 106186552 1524876266 0 34494579 1569711189
       253    1 dm-1 55444 0 443552 845705 83094 0 664752 3689496 0 51922 4535201
       22    0 hdc 8 9 136 148 0 0 0 0 0 110 148
       2    0 fd0 0 0 0 0 0 0 0 0 0 0 0
       9    0 md0 0 0 0 0 0 0 0 0 0 0 0
  EOS
end
