require File.expand_path('../../test_helper.rb', __FILE__)
require File.expand_path('../passenger_memory_stats.rb', __FILE__)

class PassengerMemoryStatsTest < Test::Unit::TestCase
  def test_nginx_only
    stub_command_with FIXTURES[:nginx_only]
    assert_equal([{
      "nginx_private_total"     => "26.0 MB",
      "nginx_processes"         => "5",
      "nginx_vmsize_total"      => "271.6 MB",
      "passenger_private_total" => "2251.4 MB",
      "passenger_processes"     => "16",
      "passenger_vmsize_total"  => "4377.8 MB",
    }], PassengerMemoryStats.new(nil, {}, {}).run[:reports])
  end

  def test_apache_only
    stub_command_with FIXTURES[:apache_only]
    assert_equal([{
      "apache_private_total"    => "7.6 MB",
      "apache_processes"        => "4",
      "apache_vmsize_total"     => "1083.3 MB",
      "passenger_private_total" => "214.8 MB",
      "passenger_processes"     => "6",
      "passenger_vmsize_total"  => "636.3 MB",
    }], PassengerMemoryStats.new(nil, {}, {}).run[:reports])
  end

  protected

  def stub_command_with(fixture)
    PassengerMemoryStats.any_instance.expects(:`).with("passenger-memory-stats 2>&1").returns(fixture).once
    `echo''>/dev/null` # total hack: the plugin checks $? (child process exit status) -- this sets $?
  end

  FIXTURES = YAML.load(<<-EOS)
    :nginx_only: |
      ------- Apache processes --------

      ### Processes: 0
      ### Total private dirty RSS: 0.00 MB


      ---------- Nginx processes ----------
      PID    PPID   VMSize   Private  Name
      -------------------------------------
      17881  1      49.8 MB  0.6 MB   nginx: master process /usr/sbin/nginx -c /etc/nginx/nginx.conf
      18419  17881  54.3 MB  5.2 MB   nginx: worker process
      18516  17881  54.4 MB  5.2 MB   nginx: worker process
      18556  17881  58.3 MB  9.2 MB   nginx: worker process
      18557  17881  54.8 MB  5.8 MB   nginx: worker process
      ### Processes: 5
      ### Total private dirty RSS: 26.05 MB


      ----- Passenger processes ------
      PID    VMSize    Private   Name
      --------------------------------
      18381  160.9 MB  7.9 MB    PassengerNginxHelperServer /usr/lib/passenger ruby 3 4 0 40 0 3600 1 deploy 1000 1000 /tmp/passenger.17881
      18391  39.9 MB   8.4 MB    Passenger spawn server
      18632  308.8 MB  171.5 MB  Rails: /data/www/current
      18634  313.6 MB  176.0 MB  Rails: /data/www/current
      499    312.1 MB  173.5 MB  Rails: /data/www/current
      505    313.9 MB  175.3 MB  Rails: /data/www/current
      509    312.3 MB  173.5 MB  Rails: /data/www/current
      23732  296.4 MB  157.5 MB  Rails: /data/www/current
      23734  298.5 MB  159.9 MB  Rails: /data/www/current
      23736  305.5 MB  167.0 MB  Rails: /data/www/current
      23738  302.9 MB  164.0 MB  Rails: /data/www/current
      23740  302.6 MB  163.8 MB  Rails: /data/www/current
      23742  295.2 MB  156.2 MB  Rails: /data/www/current
      2982   230.0 MB  90.6 MB   Passenger ApplicationSpawner: /data/www/current
      3001   293.2 MB  154.2 MB  Rails: /data/www/current
      3191   292.0 MB  152.1 MB  Rails: /data/www/current
      ### Processes: 16
      ### Total private dirty RSS: 2251.22 MB

    :apache_only: |
      ---------- Apache processes ----------
      PID    PPID   VMSize    Private  Name
      --------------------------------------
      12715  23095  129.9 MB  0.6 MB   /usr/sbin/apache2 -k start
      12731  23095  411.8 MB  3.3 MB   /usr/sbin/apache2 -k start
      12759  23095  411.7 MB  3.2 MB   /usr/sbin/apache2 -k start
      23095  1      129.9 MB  0.5 MB   /usr/sbin/apache2 -k start
      ### Processes: 4
      ### Total private dirty RSS: 7.61 MB


      -------- Nginx processes --------

      ### Processes: 0
      ### Total private dirty RSS: 0.00 MB


      ----- Passenger processes -----
      PID    VMSize    Private  Name
      -------------------------------
      778    128.3 MB  54.1 MB  Rails: /var/www/apps/tempo/current
      6085   125.7 MB  50.0 MB  Passenger ApplicationSpawner: /var/www/apps/wifi/current
      6315   123.5 MB  45.4 MB  Passenger ApplicationSpawner: /var/www/apps/shapewiki/current
      12726  89.8 MB   1.5 MB   /usr/local/rvm/gems/ruby-1.9.1-p376/gems/passenger-2.2.9/ext/apache2/ApplicationPoolServerExecutable 0 /usr/local/rvm/gems/ruby-1.9.1-p376/gems/passenger-2.2.9/bin/passenger-spawn-server  /usr/local/bin/passenger_ruby  /tmp/passenger.23095
      12727  39.2 MB   11.6 MB  Passenger spawn server
      21162  129.8 MB  52.2 MB  Rails: /var/www/apps/wifi/current
      ### Processes: 6
      ### Total private dirty RSS: 214.95 MB
  EOS
end
