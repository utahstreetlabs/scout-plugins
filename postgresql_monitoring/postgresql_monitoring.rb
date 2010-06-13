class PostgresqlMonitoring< Scout::Plugin
  # need the ruby-pg gem
  needs 'pg'
  
  OPTIONS=<<-EOS
    user:
      name: PostgreSQL username
      notes: Specify the username to connect with
    password:
      name: PostgreSQL password
      notes: Specify the password to connect with
    host:
      name: PostgreSQL host
      notes: Specify the host name of the PostgreSQL server. If the value begins with
              a slash it is used as the directory for the Unix-domain socket. An empty
              string uses the default Unix-domain socket.
      default: localhost
    port:
      name: PostgreSQL port
      notes: Specify the port to connect to PostgreSQL with
      default: 5432
  EOS

  NON_COUNTER_ENTRIES = ["numbackends"]
  
  def build_report
    now = Time.now
    report = {}
    
    begin
      pgconn = PGconn.new(:host=>option(:host), :user=>option(:user), :password=>option(:password), :port=>option(:port).to_i, :dbname=>'postgres')
    rescue PGError => e
      return errors << {:subject => "Unable to connect to PostgreSQL.",
                        :body => "Scout was unable to connect to the PostgreSQL server: #{e.backtrace}"}
    end
    
    result = pgconn.exec('SELECT sum(idx_tup_fetch) AS "rows_select_idx", 
                                 sum(seq_tup_read) AS "rows_select_scan", 
                                 sum(n_tup_ins) AS "rows_insert", 
                                 sum(n_tup_upd) AS "rows_update",
                                 sum(n_tup_del) AS "rows_delete",
                                 (sum(idx_tup_fetch) + sum(seq_tup_read) + sum(n_tup_ins) + sum(n_tup_upd) + sum(n_tup_del)) AS "rows_total"
                          FROM pg_stat_user_tables;')
    
    row = result[0]
    row.each do |name, val|
      if NON_COUNTER_ENTRIES.include?(name)
        report[name] = val.to_i
      else
        report[name] = calculate_counter(now, name, val.to_i)
      end
    end

    result = pgconn.exec('SELECT sum(numbackends) AS "numbackends", 
                                 sum(xact_commit) AS "xact_commit", 
                                 sum(xact_rollback) AS "xact_rollback", 
                                 sum(xact_commit+xact_rollback) AS "xact_total", 
                                 sum(blks_read) AS "blks_read", 
                                 sum(blks_hit) AS "blks_hit"
                          FROM pg_stat_database;')
    row = result[0]
    row.each do |name, val|
      if NON_COUNTER_ENTRIES.include?(name)
        report[name] = val.to_i
      else
        report[name] = calculate_counter(now, name, val.to_i)
      end
    end
    
    if report['blks_hit'] and report['blks_read'] and report['blks_hit']>0.0 and report['blks_read']>0.0
      report['blks_cache_pc'] = (report['blks_hit'] / (report['blks_hit']+report['blks_read']).to_f * 100).to_i
    else
      report['blks_cache_pc'] = nil
    end

    report(report) if report.values.compact.any?
  end

  private
  def calculate_counter(current_time, name, value)
    result = nil
    # only check if a past run has a value for the specified query type
    if memory(name) && memory(name).is_a?(Hash)
      last_time, last_value = memory(name).values_at('time', 'value')
      # We won't log it if the value has wrapped
      if last_value and value >= last_value
        elapsed_seconds = current_time - last_time
        elapsed_seconds = 1 if elapsed_seconds < 1
        result = value - last_value

        # calculate per-second
        result = result / elapsed_seconds.to_f
      end
    end

    remember(name => {:time => current_time, :value => value})

    result
  end
end
