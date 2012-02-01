class MongoOverview < Scout::Plugin
  OPTIONS=<<-EOS
    host:
      name: Mongo Server
      notes: Where mongodb is running. 
      default: localhost
    username:
      notes: Leave blank unless you have authentication enabled. 
      attributes: advanced
    password:
      notes: Leave blank unless you have authentication enabled. 
      attributes: advanced,password
    port:
      name: Port
      default: 27017
      notes: MongoDB standard port is 27017. 
  EOS

  needs 'mongo'

  def build_report 

    # check if options provided
    @host     = option('host') 
    @port     = option('port')
    if [@host,@port].compact.size < 2
      return error("Connection settings not provided.", "The host and port must be provided in the settings.")
    end
    @username = option('username')
    @password = option('password')

    begin
      connection = Mongo::Connection.new(@host,@port,:slave_ok=>true)
    rescue Mongo::ConnectionFailure
      return error("Unable to connect to the MongoDB Daemon.","Please ensure it is running on #{@host}:#{@port}\n\nException Message: #{$!.message}")
    end
    
    # Connect to the database
    @admin_db = connection.db('admin')
    get_replica_set_status
  end
  
  def get_replica_set_status
    replset_status = @admin_db.command({'replSetGetStatus' => 1}, :check_response => false)
    
    unless replset_status['ok'] == 1
      return error("Node isn't a member of a Replica Set","Unable to fetch Replica Set status information. Error Message:\n\n#{replset_status['errmsg']}")
    end
    
    member_state = case replset_status['myState']
      when 0 
        'Starting Up'
      when 1 
        'Primary'
      when 2 
        'Secondary'
      when 3 
        'Recovering'
      when 4 
        'Fatal'
      when 5 
        'Starting up (forking threads)'
      when 6 
        'Unknown'
      when 7 
        'Arbiter'
      when 8 
        'Down'
      when 9 
        'Rollback'
    end
    
    report(:name => replset_status['set'])
    report(:member_state => member_state)
    report(:member_state_num => replset_status['myState'])

    primary = replset_status['members'].detect {|member| member['state'] == 1}
    if primary
      current_member = replset_status['members'].detect do |member|
        member['self']
      end
      
      if current_member
        report(:replication_lag => current_member['optimeDate'] - primary['optimeDate'])
      end
    end  
    report(:member_healthy => current_member['health'] ? 1 : 0)
  end  
end
