require "time"

# MySQL Slow Queries Monitoring plug in for scout.
# Created by Robin "Evil Trout" Ward for Forumwarz, based heavily on the Rails Request
# Monitoring Plugin.
#
# See: http://blog.forumwarz.com/2008/5/27/monitor-slow-mysql-queries-with-scout
#

class ScoutMysqlSlow < Scout::Plugin
  def build_report
    begin
      require "elif"
    rescue LoadError
      begin
        require "rubygems"
        require "elif"
      rescue LoadError
        error :subject => "Couldn't load Elif.",
              :body    => "The Elif library is required by " +
                           "this plugin." 
      end
    end
            
    if option("mysql_slow_log").nil? or option("mysql_slow_log").strip.length == 0
      return error(:subject => "A path to the MySQL Slow Query log file wasn't provided.")
    end

  
    slow_queries = []
    sql = []
    very_slow_query_count = 0
    slow_query_count = 0
    
    slow_queries_text = ''
    report_data = { :slow_query_count => 0,
                    :very_slow_query_count => 0 }
    
    max_query_time = option("max_query_time").to_i
    Elif.foreach(option("mysql_slow_log")) do |line|
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
        
        t2 = memory(:last_run) || Time.now
        if t < t2
          break
        else
          slow_queries.each do |sq|
            slow_queries_text += "#{sq[:sql]}Took: #{sq[:time]}s\n\n"
          end
          report_data[:very_slow_query_count] += very_slow_query_count
          report_data[:slow_query_count] += slow_query_count
          
          very_slow_query_count = slow_query_count = 0
        end
        
      elsif line !~ /^\#/
        sql << line
      end
    end  
    
    if report_data and (count = report_data[:very_slow_query_count].to_i and count > 0)
      alert(:subject => "Maximum Query Time (#{option("max_query_time").to_s} sec) exceeded on #{count} #{count > 1 ? 'queries' : 'query'}",
            :body => slow_queries_text)
    end
    remember(:last_run,Time.now)
    report(report_data)

    rescue
      error(:subject => "Couldn't parse log file.",
                    :body    => $!.message)
  end
end
