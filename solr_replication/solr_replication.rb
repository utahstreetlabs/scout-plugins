class SolrReplication < Scout::Plugin
  needs 'open-uri'

  OPTIONS=<<-EOS
  master:
    default: http://192.168.0.1:8983
  slave:
    default: http://localhost:8765
  EOS

  def build_report
    replication_path = '/solr/admin/replication/index.jsp'
    rex = /Generation: (\d+)/
    master = open(option(:master)+replication_path).read.match(rex)[1]
    slave = open(option(:slave)+replication_path).read.match(rex)[1]
    if master and slave
      report 'delay' => master.to_i - slave.to_i
    else
      error "Incorrect values found master:#{master} slave:#{slave}"
    end
  end
end