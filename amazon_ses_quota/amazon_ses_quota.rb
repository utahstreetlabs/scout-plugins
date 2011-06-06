# Amazon Simple Email Service Quota monitor
# Monitors the maximum number of emails you can send in a 24 hour period and actual sent emails.
# Created by Valery Vishnyakov
class AwsSesQuota < Scout::Plugin
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

      response = ses.quota

      if (response.sent_last_24_hours.to_i >= response.max_24_hour_send.to_i)
        alert('You have reached the maximum quota per 24 hours') unless memory(:notified)
        remember(:notified => true)
      else
        remember(:notified => false)
      end

      report :sent => response.sent_last_24_hours,
        :max  => response.max_24_hour_send
  end

end