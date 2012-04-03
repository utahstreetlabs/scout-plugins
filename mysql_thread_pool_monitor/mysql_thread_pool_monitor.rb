require 'time'
require 'date'

# Created by Jon Bardin
class MysqlThreadPoolMonitor < Scout::Plugin

  needs 'mysql'

  OPTIONS=<<-EOS
  host:
    name: Host
    notes: The host to monitor
    default: 127.0.0.1
  port:
    name: Port
    notes: The port number on the host
    default: 3306
  username:
    name: Username
    notes: The MySQL username to use
    default: root
  password:
    name: Password
    notes: The password for the mysql user
    default:
    attributes: password
  EOS

  HEADERS_TO_TRACK_RATE_OF = %w{CONNECTIONS_STARTED CONNECTIONS_CLOSED QUERIES_QUEUED THREADS_STARTED PRIO_KICKUPS STALLED_QUERIES_EXECUTED BECOME_CONSUMER_THREAD BECOME_RESERVE_THREAD BECOME_WAITING_THREAD WAKE_THREAD_STALL_CHECKER SLEEP_WAITS DISK_IO_WAITS ROW_LOCK_WAITS GLOBAL_LOCK_WAITS META_DATA_LOCK_WAITS TABLE_LOCK_WAITS USER_LOCK_WAITS BINLOG_WAITS GROUP_COMMIT_WAITS FSYNC_WAITS}

  SELECT_THREAD_GROUP_STATS = "SELECT * FROM information_schema.TP_THREAD_GROUP_STATS"

  def build_report
    begin
      connection = Mysql.new(option(:host) || "localhost", option(:username) || "root", option(:password), nil, option(:port).to_i)
      result = connection.query(SELECT_THREAD_GROUP_STATS)
      thread_group_stats = fetch_all_rows_as_hash(result)
      if thread_group_stats.length > 0 then
        sum_counts = {}
        thread_group_count = thread_group_stats.length
        thread_group_stats.each { |row|
          HEADERS_TO_TRACK_RATE_OF.each { |tracked_header|
            tracked_value = row[tracked_header].to_i
            if sum_counts[tracked_header] then
              sum_counts[tracked_header] += tracked_value
            else
              sum_counts[tracked_header] = tracked_value
            end
          }
        }

        sum_counts.each { |key, value|
          counter("#{key.downcase}_rate_avg", (value.to_f / thread_group_count.to_f).to_i, :per => :minute, :round => true)
        }
      end
    rescue Mysql::Error => e
      if e.to_s.include?("Unknown table 'tp_thread_group_stats'") then
        error("MySQL thread pool plugin not installed", e.to_s)
      else
        error("Unable to connect to MySQL", e.to_s)
      end
    end
  end

  private

  def fetch_all_rows_as_hash(result)
    rows = []
    while row = result.fetch_hash
      rows << row
    end
    rows
  end

end
