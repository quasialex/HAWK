# core/ui_helpers.rb
module Hackberry
  module UIHelpers
    def big_icon(cat)
      {
        wifi: '📶', ble: '🧿', network: '🌐', payloads: '📦', phishing: '🎣',
        utils: '🧰'
      }[cat] || '🛠️'
    end
  end
end
