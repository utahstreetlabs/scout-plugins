# Returns Amazon SQS Queue Sizes
# Created by Ankur Bulsara of Scopely
class AwsSqsStatus < Scout::Plugin
  needs 'right_aws'

  OPTIONS=<<-EOS
    queues:
      name: Queue Names
      notes: Comma separated list of SQS queues to query
    awskey:
      name: AWS Access Key
      notes: Your Amazon Web Services Access key. 20-char alphanumeric, looks like 022QF06E7MXBSH9DHM02
    awssecret:
      name: AWS Secret
      notes: Your Amazon Web Services Secret key. 40-char alphanumeric, looks like kWcrlUX5JEDGMLtmEENIaVmYvHNif5zBd9ct81S
  EOS


  def build_report
    aws_key = option(:awskey)
    aws_secret = option(:awssecret)
    sqs = RightAws::SqsGen2.new(aws_key, aws_secret)

    results = {}

    queues = (option(:queues) || "").split(',')
    queues.each do |queue_name|
      results[queue_name] = sqs.queue(queue_name).size.to_i
    end

    report(results)
  end
end
