class SolrReplication < Scout::Plugin
  needs 'open-uri'

  OPTIONS=<<-EOS
  master:
    default: http://192.168.0.1:8983
  slave:
    default: http://localhost:8765
  replication_path:
    default: /solr/admin/replication/index.jsp
    notes: The path to the replication index page in the Solr Admin web interface
  EOS

  def build_report
    master_position = position_for(master_host)
    slave_position = position_for(slave_host)
    return if errors.any?
    if master_position and slave_position
      report 'delay' => master_position.to_i - slave_position.to_i
    else
      error "Incorrect master and slave positions found","master:#{master_position.inspect}\nslave:#{slave_position.inspect}"
    end
  end

  private

  def position_for(host)
    generation_regex = /Generation: (\d+)/
    open(host).read.match(generation_regex)[1]
  rescue => e
    error "Error connecting to #{host}","Unable to connect to Solr Admin interface at: #{host}. Error:\n#{e.message}\n\nEnsure the plugin options are configured correctly."
  end

  def master_host
    "#{option(:master)}#{option("replication_path")}"
  end

  def slave_host
    "#{option(:slave)}#{option("replication_path")}"
  end
end
