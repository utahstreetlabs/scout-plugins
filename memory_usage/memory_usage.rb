class MemoryUsage < ScoutAgent::Plugin
  TEST_USAGE = "#{File.basename($0)} max_swap_used MAX_SWAP_USED max_swap_ration MAX_SWAP_RATIO"
  
  UNITS = { "b" => 1, 
            "k" => 1024,
            "m" => 1024 * 1024,
            "g" => 1024 * 1024 * 1024 }
            
  def build_report
    top_output = `top -#{RUBY_PLATFORM.include?('darwin') ? 'l' : 'n'} 1`
    mem        = top_output[/^(?:Phys)?Mem:.+/i] or raise "Missing mem"
    swap       = top_output[/^Swap:.+/i]

    report_memory(mem,  "mem")
    report_percent("mem")
    if swap           
      report_memory(swap, "swap")
      report_percent("swap")
      if swap_used = reports.last[:swap_used]
        ratio  = ( swap_used.to_f / reports.last[:mem_used] ).round        
        
        report(:swap_ratio => ratio)

        max = @options["max_swap_used"].to_i*UNITS["m"]
        if max > 0 and swap_used > max
          alert "Maximum Swap Exceeded (#{swap_used})", ''
        end
        max = @options["max_swap_ratio"].to_i
        if max > 0 and ratio > max
          alert "Maximum Swap Ratio Exceeded (#{ratio})", ''
        end
      end
    end
    @report
  rescue => e
    error "Couldn't use `top` as expected.", "#{e.message}\n#{e.backtrace}" #$!.message
  end
  
  private
  
  def report_memory(data, type)
    data.scan(/(\d+|\d+\.\d+)([bkmg])\s+(\w+)/i) do |amount, unit, label|
      report( "#{type}_#{label.downcase}".to_sym => (amount.to_f * UNITS[unit.downcase]).round )
    end
  end
  
  def report_percent(type)
    used = (reports.last["#{type}_used".to_sym]) or return
    free = (reports.last["#{type}_free".to_sym]) or return
    report( "#{type}_used_percent".to_sym => (used.to_f / (used + free)  * 100).round )
  end
end
