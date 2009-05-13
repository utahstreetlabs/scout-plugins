require "time"
require "digest/md5"

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
      return error(:subject => "A path to the MySQL Slow Query log file wasn't provided.",
      :body => "The full path to the slow queries log must be provided. Learn more about enabling the slow queries log here: http://dev.mysql.com/doc/refman/5.1/en/slow-query-log.html")
    end

    slow_query_count = 0
    slow_queries = []
    sql = []
    last_run = memory(:last_run) || Time.now
    current_time = Time.now
    Elif.foreach(option("mysql_slow_log")) do |line|
      if line =~ /^# Query_time: (\d+) .+$/
        query_time = $1.to_i
        slow_queries << {:time => query_time, :sql => sql.reverse}
        sql = []
      elsif line =~ /^\# Time: (.*)$/
        t = Time.parse($1) {|y| y < 100 ? y + 2000 : y}
        
        t2 = last_run
        if t < t2
          break
        else
          slow_queries.each do |sq|
            slow_query_count +=1
            # calculate importance
            importance = 0
            importance += 1 if sq[:time] > 3
            importance += 1 if sq[:time] > 10
            importance += 1 if sq[:time] > 30
            parsed_sql = sq[:sql].join
            hint(:title => "#{sq[:time]}s: #{parsed_sql[0..50]}...",
                 :description => sq[:sql],
                 :token => Digest::MD5.hexdigest("slow_query_#{parsed_sql.size > 250 ? parsed_sql[0..250] + '...' : parsed_sql}"),
                 :importance=> importance,
                 :tag_list=>'slow_query')
          end
        end
        
      elsif line !~ /^\#/
        sql << line
      end
    end  

    elapsed_seconds = current_time - last_run
    elapsed_seconds = 1 if elapsed_seconds < 1

    # calculate per-second
    report(:slow_queries => slow_query_count/elapsed_seconds.to_f)
    
    remember(:last_run,Time.now)
  end
end
