require 'rubygems'
require 'right_aws'

class AmazonSQSStats < Scout::Plugin

  def build_report

    if option('sqs_protocol_version').to_i == 1
      sqs = RightAws::Sqs.new(option('access_key'), option('secret_access_key'))
    else
      sqs = RightAws::SqsGen2.new(option('access_key'), option('secret_access_key')) 
    end
    
    queue = sqs.queue(option('queue_name'))
    size = queue.size

    if option('max_size') && size > option('max_size').to_i
      alert( :subject => "Maximum size of #{option('queue_name')} queue exceeded.")
    end

    report( :queue_size => size )

  rescue
    error( :subject => "Error talking to lighthouse or parsing xml", :body => $!.message)
  end
  
end