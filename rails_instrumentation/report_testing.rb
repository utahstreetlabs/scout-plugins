require 'time'

r1 = {"actions"=>

{"info/support"=>{"runtime_max"=>487.0, "num_requests"=>6, 
"render_runtime_avg"=>193.676233291626, "db_runtime_avg"=>9.69983333333333, 
"other_runtime_max"=>68.7489188537598, "runtime_avg"=>265.0, 
"other_runtime_avg"=>61.6239333750407, 
"queries"=>[[[2.579, 0], [0.662, 1], [0.195, 2], [0.125, 3], [0.195, 4], [0.471, 5]], 
[[2.588, 0], [0.664, 1], [0.526, 2], [0.16, 3], [0.197, 4], [0.601, 5]], [[5.751, 0], 
[0.933, 1], [0.201, 2], [0.175, 3], [0.192, 4], [0.417, 5]], [[12.458, 0], [5.031, 1], 
[0.185, 2], [0.151, 3], [0.19, 4], [0.42, 5]], [[14.049, 0], [1.146, 1], [0.21, 2], 
[0.16, 3], [0.193, 4], [0.435, 5]], [[11.301, 0], [1.037, 1], [0.183, 2], [0.162, 3]]], 
"render_runtime_max"=>403.141021728516, "db_runtime_max"=>17.489}, 

"info/index"=>{"runtime_max"=>501.0, "num_requests"=>1, 
"render_runtime_avg"=>421.083927154541, 
"db_runtime_avg"=>4.47, 
"other_runtime_max"=>75.446072845459, 
"runtime_avg"=>501.0, "other_runtime_avg"=>75.446072845459, 
"queries"=>[[[3.743, 0], [0.727, 1], [0.224, 2], [0.165, 3], [0.237, 4], [0.489, 5]]], 
"render_runtime_max"=>421.083927154541, "db_runtime_max"=>4.47}}, 

"num_requests"=>7, 
"scout_time"=>Time.parse("Wed Jun 03 20:37:57 UTC 2009"), 
"queries"=>["SHOW FIELDS FROM `accounts`", 
"SELECT * FROM `accounts` WHERE (`accounts`.`deleted_at` IS NULL AND `accounts`.`param` IS NULL) LIMIT ?", 
"BEGIN", "COMMIT", "SET SQL_AUTO_IS_NULL=?", "SELECT * FROM `sessions` WHERE (session_id = ?) LIMIT ?"], 
"avg_request_time"=>298.714285714286}

r2 = {"actions"=>{"info/support"=>{"runtime_max"=>803.0, "num_requests"=>1, 
  "render_runtime_avg"=>245.510816574097, "db_runtime_avg"=>3.432, "other_runtime_max"=>54.0571834259033, 
  "runtime_avg"=>303.0, "other_runtime_avg"=>54.0571834259033, "queries"=>[[[2.769, 0], [0.663, 1], [0.208, 2], [0.164, 3]]], 
  "render_runtime_max"=>245.510816574097, "db_runtime_max"=>3.432}, 
  "info/index"=>{"runtime_max"=>322.0, "num_requests"=>1, "render_runtime_avg"=>206.699132919312, 
    "db_runtime_avg"=>30.435, "other_runtime_max"=>84.8658670806885, "runtime_avg"=>322.0, 
    "other_runtime_avg"=>84.8658670806885, 
    "queries"=>[[[28.103, 0], [2.332, 1], [0.226, 2], [0.422, 4], [0.658, 3], [0.277, 5], [0.407, 6]]], 
    "render_runtime_max"=>206.699132919312, "db_runtime_max"=>30.435}, 
    "plugin_urls/index"=>{"runtime_max"=>532.0, "num_requests"=>1, 
      "render_runtime_avg"=>155.802011489868, "db_runtime_avg"=>60.591, "other_runtime_max"=>315.606988510132, 
      "runtime_avg"=>532.0, "other_runtime_avg"=>315.606988510132, 
      "queries"=>[[[2.536, 0], [0.629, 1], [26.602, 7], [0.707, 8], [25.557, 9], [3.574, 10], [0.986, 11], [0.175, 2], [0.157, 3], [0.194, 5], [0.389, 6]]], "render_runtime_max"=>155.802011489868, "db_runtime_max"=>60.591}}, "num_requests"=>3, 
      "scout_time"=>Time.parse("Fri Jun 05 19:52:58 UTC 2009"), "queries"=>["SHOW FIELDS FROM `accounts`", "SELECT * FROM `accounts` WHERE (`accounts`.`deleted_at` IS NULL AND `accounts`.`param` IS NULL) LIMIT ?", "BEGIN", "COMMIT", "INSERT INTO `sessions` (`updated_at`, `session_id`, `data`, `created_at`) VALUES(?, ?, ?, ?)", "SET SQL_AUTO_IS_NULL=?", "SELECT * FROM `sessions` WHERE (session_id = ?) LIMIT ?", "SHOW FIELDS FROM `clients`", "SELECT * FROM `clients` WHERE (`clients`.`id` IS NULL) LIMIT ?", "SELECT * FROM `plugin_urls` WHERE (approved = ? and scout_version >= ? ) ORDER BY plugins_count DESC", "SHOW FIELDS FROM `plugin_urls`", "SELECT count(*) AS count_all FROM `plugin_urls` WHERE (approved = ? and scout_version >= ?)"], "avg_request_time"=>385.666666666667}

AVG_FIELDS = %w(render_runtime_avg db_runtime_avg runtime_avg other_runtime_avg)

# Merges data from the +k+ controller/action as the value.
def merge_data(k,v)
  p "merging into #{k}"
  data = @report_data[k]
  
  # compares the value for each of these fields with the existing value, keeping the max value
  %w(runtime_max other_runtime_max render_runtime_max db_runtime_max).each do |field|
    if v[field] > data[field] 
      data[field] = v[field]
      # marks the maximum runtime w/the scout_time
      if field == 'runtime_max'
        data['scout_time'] = v['scout_time']
      end
    end
  end
  
  # sum the values of these ... before reporting, divide by the num_requests to record avg, 
  # dropping the sum key
  AVG_FIELDS.each do |field|
    data[field+'_sum'] ||= data[field]*data['num_requests']
    data[field+'_sum'] += v[field]*v['num_requests']
  end
  
  # sum
  %w(num_requests).each do |field|
    data[field] += v[field]
  end
  
  @report_data[k] = data
end # end merge_data

# For all fields that contains averages, divides the sum by / num_requests to obtain
# the final average.
def average_summed_data
  AVG_FIELDS.each do |field|
    @report_data.each do |action,data|
      if sum = data.delete(field+'_sum')
        p "averaging sum for #{action} and #{field}"
        data[field] = sum/data['num_requests']
      end
    end
  end
end # end average_summed_data

def create_action_reports
  @report_data.each do |k,v|
    time = v.delete('scout_time')
    data = {k => v, 'scout_time' => time}
    p data
  end
end # end create_action_reports

# Builds up the summary data:
# - num_requests
# - avg_request_time
# - scout_time (most recent)
def create_summary_report
  sum = @summary_data.delete('avg_request_time_sum')
  @summary_data['avg_request_time'] = sum/@summary_data['num_requests']
  p @summary_data
end

# Older versions of the plugin use +time+, newer versions use +scout_time+. 
def get_time(message)
  message['scout_time'] || message['time']
end

messages = [r1,r2]

# from all of the reports, creates 1 report for each action. 
@report_data = Hash.new
@summary_data = {'num_requests' => 0,'avg_request_time_sum' => 0,'scout_time' => nil}

messages.each do |message|
  @summary_data['num_requests'] += message['num_requests']
  @summary_data['avg_request_time_sum'] += message['avg_request_time']*message['num_requests']
  @summary_data['scout_time'] = message['scout_time']
  
  actions = message['actions']
  actions.each { |k,v| v.merge!( 'scout_time' => get_time(message) ) }
  p "found #{actions.size} actions"
  actions.each do |k,v|
    # if the action hasn't been aggregated yet, add it. otherwise, 
    # merge in the data.
    if @report_data[k].nil?
      @report_data[k] = v
    else
      p "exists for #{k}"
      merge_data(k,v)
    end
  end
end

average_summed_data

# create reports for actions
create_action_reports

# add in summary data
create_summary_report


# create summary report
 