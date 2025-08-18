# core/ifaces.rb
require 'open3'
module Hackberry
  module Ifaces
    module_function

    def sh(cmd)
      out, _err, _st = Open3.capture3({'LC_ALL'=>'C'}, cmd)
      out
    end

    def wifi
      parse_ip_links.select { |i| i[:name] =~ /wl|wlan/i }
    end

    def wifi_mon
      parse_ip_links.select { |i| i[:name] =~ /mon$/ }
    end

    def lan
      parse_ip_links.select { |i| i[:name] =~ /^(e(th|n)|usb)/i }
    end

    def ble
      out = sh('hciconfig -a || true')
      out.scan(/^(hci\d+)/).flatten
    end

    def parse_ip_links
      out = sh('ip -o link show')
      out.lines.map do |l|
        # 2: wlan0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 ...
        if l =~ /\d+:\s+([^:]+):\s+<([^>]+)>/ then { name: $1, flags: $2.split(',') } end
      end.compact
    end

    def names(arr)
      arr.map { |h| h.is_a?(Hash) ? h[:name] : h }
    end
  end
end
