class MongrelClusterMonitor < Scout::Plugin
  def build_report
    mongrel_configuration_dir = option("mongrel_cluster_configuration_dir") ||  "/etc/mongrel_cluster/"
    mongrel_rails_command = option("mongrel_rails_command") || "mongrel_rails"
    res={}
    if !File.exist?(mongrel_configuration_dir)
      error(:subject=>"mongrel_configuration_dir: #{mongrel_configuration_dir} does not exist -- check options")
      return
    end
    Dir.chdir(mongrel_configuration_dir) do
      configs = Dir.glob("*.{yml,conf}")

      unless configs.empty?        
        configs.each do |config|
          application_name = config.gsub(".conf", "").gsub(".yml", "")
          mongrel_status = `#{mongrel_rails_command} cluster::status -C #{mongrel_configuration_dir}/#{config}`
          if mongrel_status.empty? 
            raise "mongrel_rails command: `#{mongrel_rails_command}` not found or no status information available"
          elsif mongrel_status.include?("missing")
            if memory(application_name)
              alert(:subject=>"Still down: one  or more mongrels for #{application_name}. Attempting Start.", :body=>mongrel_status)
              mongrel_start = `#{mongrel_rails_command} cluster::start -C #{mongrel_configuration_dir}/#{config}`
            else
              alert(:subject => "Down: one or more mongrels for #{application_name}", :body=>mongrel_status)
              remember(application_name,Time.now)
            end
            res[application_name] = 0
          else
            res[application_name] = 1
            remember(application_name,nil)
          end
        end
      else
        alert(:subject => "No mongrel configuration files found.")
      end
    end
    report(res)

  end
end
