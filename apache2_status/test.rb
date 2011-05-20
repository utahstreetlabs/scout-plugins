require File.expand_path('../../test_helper.rb', __FILE__)
require File.expand_path('../apache2_status.rb', __FILE__)



class Apache2StatusTest < Test::Unit::TestCase

  def setup
    @options=parse_defaults("apache2_status")
  end

  def teardown
  end

  def test_clean_run
    # Stub the plugin instance where necessary and run
    # @plugin=PluginName.new(last_run, memory, options)
    #                        date      hash    hash
    `echo 0 > /dev/null` # ugh. Sets $? so the stubbed shell commands suffice when we check $? in the plugin. Not recommended.
    @plugin=Apache2Status.new(nil,{},@options)
    @plugin.stubs(:shell).with("ps aux | grep apache2 | grep -v grep | grep -v ruby | awk '{print $5}'").returns(FIXTURES[:ps]).once
    @plugin.stubs(:shell).with("/usr/sbin/apache2ctl status").returns(FIXTURES[:apache2ctl]).once

    res= @plugin.run()

    assert res[:alerts].empty?
    assert res[:errors].empty?
    reports = res[:reports].inject({}){|memo,value|memo.merge(value) } # condense the array of hashes into one
    puts reports.inspect
#    assert_equal 1.43149185180664, reports[:apache_reserved_memory_size]
    assert_equal 2.212890625, reports[:kb_second]
    assert_equal 7, reports[:requests_being_processed]
  end

  FIXTURES=YAML.load(<<-EOS)
    :ps: |
      93424
      437972
      438048
      92928
      438656
    :apache2ctl: |
      Apache Server Status for localhost

      Server Version: Apache/2.2.14 (Ubuntu) mod_ssl/2.2.14 OpenSSL/0.9.8k
          Phusion_Passenger/2.2.11
      Server Built: Apr 13 2010 20:22:19

      -------------------------------------------------------------------------------

      Current Time: Friday, 20-May-2011 11:15:56 PDT
      Restart Time: Sunday, 15-May-2011 05:14:44 PDT
      Parent Server Generation: 1
      Server uptime: 5 days 6 hours 1 minute 12 seconds
      Total accesses: 208288 - Total Traffic: 980.6 MB
      CPU Usage: u345.61 s184.88 cu0 cs0 - .117% CPU load
      .459 requests/sec - 2266 B/second - 4936 B/request
      7 requests currently being processed, 68 idle workers

      ____________K______K_____.......................................
      ________W__________KK____.......................................
      _____K______________K____.......................................
      ................................................................
      ................................................................
      ................................................................
      ................................................................
      ................................................................
      ................................................................
      ................................................................
      ................................................................
      ................................................................
      ................................................................
      ................................................................
      ................................................................
      ................................................................

      Scoreboard Key:
      "_" Waiting for Connection, "S" Starting up, "R" Reading Request,
      "W" Sending Reply, "K" Keepalive (read), "D" DNS Lookup,
      "C" Closing connection, "L" Logging, "G" Gracefully finishing,
      "I" Idle cleanup of worker, "." Open slot with no current process
  EOS

end