class PassengerMemoryStats < Scout::Plugin
  def build_report
    cmd  = option(:passenger_memory_stats_command) || "passenger-memory-stats"
    data = `#{cmd} 2>&1`
    if $?.success?
      stats = parse_data(data)
      report(stats)
      stats.each do |name, total|
        short_name = name.sub(/_total\z/, "")
        max        = option("max_#{short_name}").to_f
        next unless max.nonzero?
        num        = total.to_f
        mem_name   = "#{name}_failure"
        human_name = short_name.capitalize.
                                gsub(/_([a-z])/) { " #{$1.capitalize}"}.
                                gsub("Vms", "VMS")
        if num > max and not memory(mem_name)
          alert "Maximum #{human_name} Exceeded (#{total})", ''
          remember(mem_name => true)
        elsif num < max and memory(mem_name)
          alert "Maximum #{human_name} Has Dropped Below Limit (#{total})", ''
          memory.delete(mem_name)
        else
          remember(mem_name => memory(mem_name))
        end
      end
    # The following exception will occassially be raised by passenger-memory-stats:
    # /usr/local/rvm/gems/ruby-1.9.2-p136/gems/passenger-3.0.2/lib/phusion_passenger/admin_tools/memory_stats.rb:247:in `split': invalid byte sequence in US-ASCII (ArgumentError) 
    # This will ignore that error.
    elsif data !~ /invalid byte sequence/
      error "Could not get data from command", "Error:  #{data}"
    end
  end

  private

  def parse_data(data)
    table        = nil
    headers      = nil
    field_format = nil
    stats        = Hash.new(0.0)

    data.each_line do |line|
      line = line.gsub(/\e\[\d+m/,'')
      if line =~ /^\s*-+\s+(Apache|Passenger|Nginx)\s+processes/
        table        = $1.downcase
        headers      = nil
        field_format = nil
      elsif table and line =~ /^\s*###\s+Processes:\s*(\d+)/
        stats["#{table}_processes"] = $1 unless $1 == "0"
      elsif table and line =~ /^[A-Za-z]/
        headers      = line.scan(/\S+\s*/)
        field_format = headers.map { |h| "A#{h.size - 1}" }.join("x").
                               sub(/\d+\z/, "*")
        headers.map! { |h| h.strip.downcase }
      elsif table and headers and line =~ /^\d/
        fields = Hash[*headers.zip(line.strip.unpack(field_format)).flatten]
        stats["#{table}_vmsize_largest"] = [as_mb(fields["vmsize"]), stats["#{table}_vmsize_largest"]].max
        stats["#{table}_private_largest"] = [as_mb(fields["private"]), stats["#{table}_private_largest"]].max
        stats["#{table}_vmsize_total"]  += as_mb(fields["vmsize"])
        stats["#{table}_private_total"] += as_mb(fields["private"])
      end
    end

    stats.each_key do |field|
      if field =~ /(?:vmsize|private)_(total|largest)\z/
        stats[field] = "#{stats[field]} MB"
      end
    end

    stats
  end

  def as_mb(memory_string)
    num = memory_string.to_f
    case memory_string
    when /\bB/i
      num / (1024 * 1024).to_f
    when /\bKB/i
      num / 1024.0
    when /\bGB/i
      num * 1024
    else
      num
    end
  end
end
