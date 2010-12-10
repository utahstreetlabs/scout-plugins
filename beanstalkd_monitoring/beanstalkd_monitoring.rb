class BeanstalkdMonitoring < Scout::Plugin
	needs 'beanstalk-client'

OPTIONS=<<-EOS
  connection_string:
    default: localhost:11300
    name: Connection String
    notes: The host and port to connect to.
EOS

	def build_report
		begin
			client = Beanstalk::Pool.new([option(:connection_string)])
		rescue Exception => e
			error("Unable to connect to beanstalkd server (#{option(:connection_string)}).")
			return
		end

		stats = client.stats
		per_second = 0

		if stats['current-jobs-ready'] > 0
			sleep 5
			now_ready = client.stats['current-jobs-ready']
			per_second = (stats['current-jobs-ready'] - now_ready) / 5.0
	 	end

		remember :ready => stats['current-jobs-ready']
		remember :per_second => per_second
		remember :buried => stats['current-jobs-buried']

		report(
			:ready => stats['current-jobs-ready'],
			:buried => stats['current-jobs-buried'],
			:reserved => stats['current-jobs-reserved'],
			:workers => stats['current-workers'],
			:per_second => per_second
		)
	end

end