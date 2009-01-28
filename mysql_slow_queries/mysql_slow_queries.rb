require "time"

# MySQL Slow Queries Monitoring plug in for scout.
# Created by Robin "Evil Trout" Ward for Forumwarz, based heavily on the Rails Request
# Monitoring Plugin.
#
# See: http://blog.forumwarz.com/2008/5/27/monitor-slow-mysql-queries-with-scout
#

class ScoutMysqlSlow < Scout::Plugin
  def run
    begin
      require "elif"
    rescue LoadError
      begin
        require "rubygems"
        require "elif"
      rescue LoadError
        return { :error => { :subject => "Couldn't load Elif.",
                             :body    => "The Elif library is required by " +
                                         "this plugin." } }
      end
    end
            
    if @options["mysql_slow_log"].nil? or @options["mysql_slow_log"].strip.length == 0
      return { :error => { :subject => "A path to the MySQL Slow Query log file wasn't provided." } }
    end

  
    slow_queries = []
    sql = []
    very_slow_query_count = 0
    slow_query_count = 0
    
    slow_queries_text = ''
    report = { :report => { :slow_query_count => 0,
                            :very_slow_query_count => 0 },
               :alerts => Array.new }

    
    max_query_time = @options["max_query_time"].to_i
    Elif.foreach(@options["mysql_slow_log"]) do |line|
      if line =~ /^# Query_time: (\d+) .+$/
        
        slow_query_count += 1


        query_time = $1.to_i
        if (max_query_time > 0) and (query_time > max_query_time)
          slow_queries << {:time => query_time, :sql => sql.reverse}
          very_slow_query_count += 1
        end
        sql = []
      elsif line =~ /^\# Time: (.*)$/
        t = Time.parse($1) {|y| y < 100 ? y + 2000 : y}
        
        t2 = @last_run || (@options["last_run"] ? Time.parse(@options["last_run"]) : Time.now)
        if t < t2
          break
        else
          slow_queries.each do |sq|
            slow_queries_text += "#{sq[:sql]}Took: #{sq[:time]}s\n\n"
          end
          report[:report][:very_slow_query_count] += very_slow_query_count
          report[:report][:slow_query_count] += slow_query_count
          
          very_slow_query_count = slow_query_count = 0
        end
        
      elsif line !~ /^\#/
        sql << line
      end
    end  
    
    if report[:report] and (count = report[:report][:very_slow_query_count].to_i and count > 0)
      report[:alerts] << {:subject => "Maximum Query Time (#{@options["max_query_time"].to_s} sec) exceeded on #{count} #{count > 1 ? 'queries' : 'query'}",
                          :body => slow_queries_text}
    end
    
    return(report)

    rescue
      { :error => { :subject => "Couldn't parse log file.",
                    :body    => $!.message } }
  end
end
