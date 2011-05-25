require File.expand_path('../../test_helper.rb', __FILE__)
require File.expand_path('../apache2_status.rb', __FILE__)

class Apache2StatusTest < Test::Unit::TestCase

  def setup
    @options=parse_defaults("apache2_status")
  end

  def teardown
    FakeWeb.clean_registry
  end

  def test_clean_run
    # Stub the plugin instance where necessary and run
    # @plugin=PluginName.new(last_run, memory, options)
    #                        date      hash    hash
    @plugin=Apache2Status.new(nil,{},@options)
    @plugin.stubs(:shell).with("ps aux | grep apache2 | grep -v grep | grep -v ruby | awk '{print $5}'").returns(FIXTURES[:ps]).once
    FakeWeb.register_uri(:get, 'http://localhost/server-status?auto', :body => FIXTURES[:valid])

    res= @plugin.run()

    assert res[:alerts].empty?, res[:alerts]
    assert res[:errors].empty?, res[:errors]

    reports = res[:reports].inject({}){|memo,value|memo.merge(value) } # condense the array of hashes into one

    assert_in_delta 1.43149185180664, reports['apache_reserved_memory_size'], 0.001
    assert_in_delta 3905630.0,        reports['bytes_per_sec'],               0.001
    assert_in_delta 14.0,             reports['busy_workers'],                0.001
    assert_in_delta 61.0,             reports['idle_workers'],                0.001
    assert_in_delta 524847.0,         reports['total_accesses'],              0.001
  end

  def test_without_extended_status
    # Stub the plugin instance where necessary and run
    # @plugin=PluginName.new(last_run, memory, options)
    #                        date      hash    hash
    @plugin=Apache2Status.new(nil,{},@options)
    @plugin.stubs(:shell).with("ps aux | grep apache2 | grep -v grep | grep -v ruby | awk '{print $5}'").returns(FIXTURES[:ps]).once
    FakeWeb.register_uri(:get, 'http://localhost/server-status?auto', :body => FIXTURES[:limited_status])

    res= @plugin.run()

    assert res[:alerts].empty?, res[:alerts]
    assert res[:errors].empty?, res[:errors]

    reports = res[:reports].inject({}){|memo,value|memo.merge(value) } # condense the array of hashes into one

    assert_in_delta 14.0,             reports['busy_workers'],                0.001
    assert_in_delta 61.0,             reports['idle_workers'],                0.001
    assert_nil reports['bytes_per_sec']
  end


  def test_404
    @plugin=Apache2Status.new(nil,{},@options)
    @plugin.stubs(:shell).with("ps aux | grep apache2 | grep -v grep | grep -v ruby | awk '{print $5}'").returns(FIXTURES[:ps]).once
    FakeWeb.register_uri(:get, 'http://localhost/server-status?auto', :body => FIXTURES[:four_oh_four])
    assert @plugin.run[:errors].length > 0
  end

  def test_bad_content
    @plugin=Apache2Status.new(nil,{},@options)
    @plugin.stubs(:shell).with("ps aux | grep apache2 | grep -v grep | grep -v ruby | awk '{print $5}'").returns(FIXTURES[:ps]).once
    FakeWeb.register_uri(:get, 'http://localhost/server-status?auto', :body => FIXTURES[:invalid])
    assert @plugin.run[:errors].length > 0
  end

  def test_bad_uri
    @plugin=Apache2Status.new(nil,{},{:server_url => 'http://-/adsf'})
    @plugin.stubs(:shell).with("ps aux | grep apache2 | grep -v grep | grep -v ruby | awk '{print $5}'").returns(FIXTURES[:ps]).once
    assert @plugin.run[:errors].length > 0
  end


  FIXTURES=YAML.load(<<-EOS)
    :ps: |
      93424
      437972
      438048
      92928
      438656
    :invalid: |
      <!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 3.2 Final//EN">
      <html><head>
      <title>Apache Status</title>
      </head><body>
      <h1>Apache Server Status for localhost</h1>

      <dl><dt>Server Version: Apache/2.2.14 (Ubuntu) Phusion_Passenger/3.0.6 mod_ssl/2.2.14 OpenSSL/0.9.8k</dt>
      <dt>Server Built: Nov 18 2010 21:20:56
      </dt></dl><hr /><dl>
      <dt>Current Time: Saturday, 21-May-2011 12:46:07 UTC</dt>
      <dt>Restart Time: Tuesday, 05-Apr-2011 19:59:53 UTC</dt>
      <dt>Parent Server Generation: 6</dt>
      <dt>Server uptime:  45 days 16 hours 46 minutes 13 seconds</dt>
      <dt>Total accesses: 20499420 - Total Traffic: 24.7 GB</dt>
      <dt>CPU Usage: u5005.43 s585.54 cu0 cs0 - .142% CPU load</dt>
      <dt>5.19 requests/sec - 6.6 kB/second - 1294 B/request</dt>
      <dt>2 requests currently being processed, 48 idle workers</dt>
      </dl><pre>................................................................
      ________________W______W_.......................................
      _________________________.......................................
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
      </pre>
      <p>Scoreboard Key:<br />
      "<b><code>_</code></b>" Waiting for Connection, 
      "<b><code>S</code></b>" Starting up, 
      "<b><code>R</code></b>" Reading Request,<br />
      "<b><code>W</code></b>" Sending Reply, 
      "<b><code>K</code></b>" Keepalive (read), 
      "<b><code>D</code></b>" DNS Lookup,<br />
      "<b><code>C</code></b>" Closing connection, 
      "<b><code>L</code></b>" Logging, 
      "<b><code>G</code></b>" Gracefully finishing,<br /> 
      "<b><code>I</code></b>" Idle cleanup of worker, 
      "<b><code>.</code></b>" Open slot with no current process</p>
      <p />


       <hr /> <table>
       <tr><th>Srv</th><td>Child Server number - generation</td></tr>
       <tr><th>PID</th><td>OS process ID</td></tr>
       <tr><th>Acc</th><td>Number of accesses this connection / this child / this slot</td></tr>
       <tr><th>M</th><td>Mode of operation</td></tr>
      <tr><th>CPU</th><td>CPU usage, number of seconds</td></tr>
      <tr><th>SS</th><td>Seconds since beginning of most recent request</td></tr>
       <tr><th>Req</th><td>Milliseconds required to process most recent request</td></tr>
       <tr><th>Conn</th><td>Kilobytes transferred this connection</td></tr>
       <tr><th>Child</th><td>Megabytes transferred this child</td></tr>
       <tr><th>Slot</th><td>Total megabytes transferred this slot</td></tr>
       </table>
      <hr>
      <table cellspacing=0 cellpadding=0>
      <tr><td bgcolor="#000000">
      </td></tr>olor="#ffffff" face="Arial,Helvetica">SSL/TLS Session Cache Status:</font></b>
      <tr><td bgcolor="#ffffff">
      cache type: <b>SHMCB</b>, shared memory: <b>512000</b> bytes, current sessions: <b>1557</b><br>subcaches: <b>32</b>, indexes per subcache: <b>133</b><br>time left on oldest entries' SSL sessions: avg: <b>8</b> seconds, (range: 1...27)<br>index usage: <b>36%</b>, cache usage: <b>56%</b><br>total sessions stored since starting: <b>2648963</b><br>total sessions expired since starting: <b>2647406</b><br>total (pre-expiry) sessions scrolled out of the cache: <b>0</b><br>total retrieves since starting: <b>857</b> hit, <b>22</b> miss<br>total removes since starting: <b>0</b> hit, <b>0</b> miss<br></td></tr>
      </table>
      <hr />
      <address>Apache/2.2.14 (Ubuntu) Server at localhost Port 80</address>
      </body></html>
    :valid: |
      Total Accesses: 524847
      Total kBytes: 949170312
      CPULoad: .110565
      Uptime: 248859
      ReqPerSec: 2.10901
      BytesPerSec: 3905630
      BytesPerReq: 1851870
      BusyWorkers: 14
      IdleWorkers: 61
      Scoreboard: ______R_____W_W_______W__.......................................___W_______W______W__WW_W......................................._____W_W___________WW____.......................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................
    :limited_status: |
      Uptime: 248859
      BusyWorkers: 14
      IdleWorkers: 61
      Scoreboard: ______R_____W_W_______W__.......................................___W_______W______W__WW_W......................................._____W_W___________WW____.......................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................
    :four_oh_four: |
      <!doctype_html_public_\"_//ietf//dtd_html_2.0//en\">_<html><head>_<title>404_not_found</title>_</head><body>_<h1>not_found</h1>_<p>the_requested_url_/server_status_was_not_found_on_this_server.</p>_</body></html>
  EOS

end