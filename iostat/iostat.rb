class Iostat < Scout::Plugin

  OPTIONS=<<-EOS
  device:
    name: Device
    notes: The device to check, eg 'sda1'. If not specified, uses the device mounted at '/'
  EOS

  def build_report
    stats = iostat(device)

    error("Device not found: #{device} -- check your plugin settings.",
          "FYI, mount returns:\n#{`mount`}") and return if !stats

    counter(:rps,   stats['rio'],        :per => :second)
    counter(:wps,   stats['wio'],        :per => :second)
    counter(:rkbps, stats['rsect'] / 2,  :per => :second)
    counter(:wkbps, stats['wsect'] / 2,  :per => :second)
    counter(:util,  stats['use'] / 10.0, :per => :second)

    if old = memory("#{device}_stats")
      ios = (stats['rio'] - old['rio']) + (stats['wio']  - old['wio'])

      if ios > 0
        await = ((stats['ruse'] - old['ruse']) + (stats['wuse'] - old['wuse'])) / ios.to_f

        report(:await => await)
      end
    end

    remember("#{device}_stats" => stats)
  end
  
  private
  COLUMNS = %w(major minor name rio rmerge rsect ruse wio wmerge wsect wuse running use aveq)

  def iostat(dev)
    IO.foreach('/proc/diskstats') do |line|
      entry = Hash[*COLUMNS.zip(line.strip.split(/\s+/).collect { |v| Integer(v) rescue v }).flatten]

      return entry if dev.include?(entry['name'])
    end

    nil
  end

  def device
    option('device') || `mount`.split("\n").grep(/ \/ /)[0].split[0]
  end

  # Would be nice to be part of scout internals
  def counter(name, value, options = {}, &block)
    current_time = Time.now

    if data = memory(name)
      last_time, last_value = data[:time], data[:value]
      elapsed_seconds       = current_time - last_time

      # We won't log it if the value has wrapped or enough time hasn't
      # elapsed
      if value >= last_value && elapsed_seconds >= 1
        if block
          result = block.call(last_value, value)
        else
          result = value - last_value
        end

        case options[:per]
        when :second, 'second'
          result = result / elapsed_seconds.to_f
        when :minute, 'minute'
          result = result / elapsed_seconds.to_f / 60.0
        else
          raise "Unknown option for ':per': #{options[:per].inspect}"
        end

        if options[:round]
          # Backward compatibility
          options[:round] = 1 if options[:round] == true

          result = (result * (10 ** options[:round])).round / (10 ** options[:round]).to_f
        end

        report(name => result)
      end
    end

    remember(name => { :time => current_time, :value => value })
  end
end
