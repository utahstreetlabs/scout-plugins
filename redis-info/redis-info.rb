class RedisMonitor < Scout::Plugin
  needs 'redis', 'yaml'

  KILOBYTE = 1024
  MEGABYTE = 1048576

  def build_report
    redis = Redis.new
    info  = redis.info

    report(:used_memory_in_kb => info[:used_memory].to_i / KILOBYTE)
    report(:used_memory_in_mb => info[:used_memory].to_i / MEGABYTE)

    # General Stats
    %w(used_memory changes_since_last_save uptime_in_seconds connected_clients connected_slaves bgsave_in_progress).each do |key|
      report(key => info[key.intern])
    end
  end
end
