class MongoOverview < Scout::Plugin
  OPTIONS=<<-EOS
    path_to_db_yml:
      label: Path to database.yml
    rails_env:
      label: Rails Environment
      default: production
  EOS

  needs 'mongo', 'yaml'

  def build_report 
    # check if database.yml path provided
    if option('path_to_db_yml').nil? or option('path_to_db_yml').empty?
      return error("The path to the database.yml file was not provided.","Please provide the full path to the MongoDB database file (ie - /var/www/apps/APP_NAME/current/config/database.yml)")
    end
    
    # check if database.yml loads
    begin
      yaml = YAML::load_file(option('path_to_db_yml'))
    rescue Errno::ENOENT
      return error("Unable to find the database.yml file", "Could not find a MongoDB config file at: #{option(:path_to_db_yml)}. Please ensure the path is correct.")
    end
    
    # Try to open a connection to Mongo
    config     = yaml[option('rails_env')]
    begin
      connection = Mongo::Connection.new(config['host'], config['port'])
    rescue Mongo::ConnectionFailure
      return error("Unable to connect to the MongoDB Daemon.","Please ensure it is running on #{config['host']}:#{config['port']}")
    end
    
    # Try to connect to the database
    @db         = connection.db(config['database'])
    begin 
      @db.authenticate(config['username'], config['password']) unless config['username'].nil?
    rescue Mongo::AuthenticationError
      return error("Unable to authenticate to MongoDB Database.",$!.message)
    end
    
    get_stats
    get_server_status
  end
  
  def get_stats
    stats = @db.stats

    report(:objects      => stats['objects'])
    report(:data_size    => stats['dataSize'])
    report(:storage_size => stats['storageSize'])
    report(:indexes      => stats['indexes'])
    report(:index_size   => stats['indexSize'])
  end
  
  def get_server_status
    stats = @db.command('serverStatus' => 1)
    counter(:btree_accesses, stats['indexCounters']['btree']['accesses'], :per => :second)
    count_and_ratio({:btree_misses => stats['indexCounters']['btree']['misses']},
                    {:btree_hits => stats['indexCounters']['btree']['hits']},
                    :btree_miss_ratio)
    counter(:btree_resets, stats['indexCounters']['btree']['resets'], :per => :second)
    # might just be best to report the ratio and store the prev values in memory. does
    # global_lock_total_time have any meaning? wouldn't it just increase?
    count_and_ratio({:global_lock_lock_time => stats['globalLock']['lockTime']},
                    {:global_lock_total_time => stats['globalLock']['totalTime']},
                    :global_lock_ratio)
    counter(:background_flushes_total, stats['backgroundFlushing']['flushes'], :per => :second)
    counter(:background_flushes_total_ms, stats['backgroundFlushing']['total_ms'], :per => :second)
    counter(:background_flushes_average_ms, stats['backgroundFlushing']['average_ms'], :per => :second)
    report(:mem_bits     => stats['mem']['bits'])      if stats['mem'] && stats['mem']['bits']
    report(:mem_resident => stats['mem']['resident'])  if stats['mem'] && stats['mem']['resident']
    report(:mem_virtual  => stats['mem']['virtual'])   if stats['mem'] && stats['mem']['virtual']
    report(:mem_mapped   => stats['mem']['mapped'])    if stats['mem'] && stats['mem']['mapped']
  end
  
  # Handles 3 metrics - a counter for the +divended+ and +divisor+ and a ratio, named +ratio_name+, 
  # of the dividend / divisor.
  def count_and_ratio(dividend,divisor,ratio_name)
    if mem_divisor = memory("_counter_#{divisor.keys.first.to_s}") and mem_dividend = memory("_counter_#{dividend.keys.first.to_s}")
      divisor_count   = divisor.values.first - mem_divisor[:value]
      dividend_count = dividend.values.first - mem_dividend[:value]
      report(ratio_name => dividend_count.to_f / divisor_count.to_f)
    end
    counter(divisor.keys.first, divisor.values.first, :per => :second)
    counter(dividend.keys.first, dividend.values.first, :per => :second)
  end
end