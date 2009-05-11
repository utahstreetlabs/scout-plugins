# 
# Created by Eric Lindvall <eric@5stops.com>
#

require 'set'

class MysqlQueryStatistics < Scout::Plugin
  ENTRIES = %w(Com_insert Com_select Com_update Com_delete).to_set

  def build_report
    begin
      require 'mysql'
    rescue LoadError => e
      return { :error => { :subject => "Unable to gather Mysql query statistics",
        :body => "Unable to find a mysql library. Please install the library to use this plugin" }
      }
    end
    logger.info @options.inspect
    user = @options['user'] || 'root'
    password, host, port, socket = @options.values_at( *%w(password host port socket) )
    
    password = nil if blank?(password)
    host     = nil if blank?(host)
    port     = nil if blank?(port)
    socket   = nil if blank?(socket)
    
    now = Time.now
    mysql = Mysql.connect(host, user, password, nil, (port ? port.to_i : nil), socket)
    result = mysql.query('SHOW /*!50002 GLOBAL */ STATUS')

    rows = []
    total = 0
    result.each do |row| 
      rows << row if ENTRIES.include?(row.first)

      total += row.last.to_i if row.first[0..3] == 'Com_'
    end
    result.free

    report_hash = {}
    rows.each do |row|
      name = row.first[/_(.*)$/, 1]
      value = calculate_counter(now, name, row.last.to_i)
      # only report if a value is calculated
      next unless value
      report(name => value)
    end


    total_val = calculate_counter(now, 'total', total)
    report('total' => total_val) if total_val
  end

  private
  
  def blank?(val)
    val.is_a?(String) and val.strip == ''
  end
  
  # Note this calculates the difference between the last run and the current run.
  def calculate_counter(current_time, name, value)
    result = nil
    # only check if a past run has a value for the specified query type
    if memory(name) && memory(name).is_a?(Hash)
      last_time, last_value = memory(name).values_at('time', 'value')
      # We won't log it if the value has wrapped
      if last_value and value >= last_value
        elapsed_seconds = last_time - current_time
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

