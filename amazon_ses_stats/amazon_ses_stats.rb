# Amazon Simple Email Service Statistics (http://aws.amazon.com/ses/)
# Displays Amazon SES automatically collected statistics regarding your sending activity:
# * Successful delivery attempts
# * Rejected messages
# * Bounces
# * Complaints

class AwsSesStatisticsPlugin < Scout::Plugin
  needs 'aws/ses'

  OPTIONS=<<-EOS
    awskey:
      name: AWS Access Key
      notes: Your Amazon Web Services Access key. 20-char alphanumeric, looks like 022QF06E7MXBSH9DHM02
    awssecret:
      name: AWS Secret
      notes: Your Amazon Web Services Secret key. 40-char alphanumeric, looks like kWcrlUX5JEDGMLtmEENIaVmYvHNif5zBd9ct81S
  EOS

  def build_report
    access_key_id = option('awskey')
    secret_access_key = option('awssecret')

    ses = AWS::SES::Base.new(
      :access_key_id     => access_key_id,
      :secret_access_key => secret_access_key
    )   
    
    response = ses.statistics
    data_point = response.data_points.sort_by{|r| Time.parse(r['Timestamp'])}.last

    
    report :bounces 		=> data_point['Bounces'],
           :deliveries 	        => data_point['DeliveryAttempts'],
           :rejects 		=> data_point['Rejects'],
	   :complaints          => data_point['Complaints'] 
  end

end