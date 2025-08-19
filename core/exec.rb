# core/exec.rb
require 'open3'
require 'fileutils'
require 'shellwords'
require 'timeout'

module Hackberry
  module Exec
    module_function

    TMUX = 'tmux -L hawk' # dedicated tmux server for HAWK

    # ---------- dirs / timestamps ----------
    def ensure_dirs(cfg)
      FileUtils.mkdir_p cfg['paths']['logs']
      FileUtils.mkdir_p cfg['paths']['captures']
      FileUtils.mkdir_p cfg['paths']['caplets'] if cfg['paths']['caplets']
    end

    def timestamp
      Time.now.utc.strftime('%Y%m%d-%H%M%S')
    end

    # ---------- shell ----------
    def run_capture(cmd)
      stdout, stderr, status = Open3.capture3({'LC_ALL'=>'C'}, cmd)
      { out: stdout, err: stderr, code: status.exitstatus }
    end

    def sh_with_env(inner)
      %(bash -lc 'export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"; export LC_ALL=C; #{inner}')
    end

    def touch_log(path)
      FileUtils.mkdir_p File.dirname(path)
      FileUtils.touch(path)
      File.chmod(0644, path) rescue nil
    end

    # ---------- tmux: start commands ----------
    # Runs a single command under tmux, teeing output to log. Returns {session:, cmd:, log:}
    def tmux_run(name:, cmd:, log_path:)
      session = "#{name}-#{timestamp}"
      touch_log(log_path)

      # safe single-quote inside single-quoted shell string
      cmd_sq = cmd.gsub("'", %q('"'"'))
      inner  = %Q{set -o pipefail; stdbuf -oL -eL '#{cmd_sq}' 2>&1 | tee -a #{Shellwords.escape(log_path)}}

      full = %(#{TMUX} new-session -d -s #{session.shellescape} #{sh_with_env(%Q{"#{inner}"})})
      system(full)
      { session: session, cmd: cmd, log: log_path }
    end

    # Runs a multi-line script (we write it to /tmp first)
    def tmux_run_script(name:, content:, log_path:)
      session = "#{name}-#{timestamp}"
      touch_log(log_path)
      script  = File.join('/tmp', "hawk_#{name}_#{timestamp}.sh")
      File.write(script, content)
      File.chmod(0755, script)

      inner = %Q{set -o pipefail; stdbuf -oL -eL /bin/bash #{script.shellescape} 2>&1 | tee -a #{Shellwords.escape(log_path)}}
      full  = %(#{TMUX} new-session -d -s #{session.shellescape} #{sh_with_env(%Q{"#{inner}"})})
      system(full)
      { session: session, cmd: "/bin/bash #{script}", log: log_path, script: script }
    end

    # An interactive login shell for the web terminal
    def tmux_new_shell(name: 'tty')
      session = "#{name}-#{timestamp}"
      start = %(#{TMUX} new-session -d -s #{session.shellescape} #{sh_with_env(%Q{"script -q -c 'bash --login -i' /dev/null"})})
      system(start)
      pane = tmux_active_pane(session)
      tmux_send_text(session, pane, "echo '[HAWK TTY] #{Time.now.utc}'; pwd; whoami; echo $SHELL")
      tmux_send_key(session, pane, 'Enter')
      { session: session, pane: pane }
    end

    # ---------- tmux: manage ----------
    def tmux_list(prefix: nil)
      out = run_capture(%(#{TMUX} ls))
      return [] unless out[:code] == 0
      sessions = out[:out].split("\n").map { |l| l.split(':').first }
      return sessions if prefix.nil? || prefix.empty?
      sessions.grep(/^#{Regexp.escape(prefix)}/)
    end

    def tmux_alive?(session)
      tmux_list.include?(session)
    end

    def tmux_kill(session)
      run_capture(%(#{TMUX} kill-session -t #{session.shellescape}))
    end

    def tmux_active_pane(session)
      out = run_capture(%(#{TMUX} list-panes -F '\#{pane_id}' -t #{session.shellescape}))
      pid = out[:out].lines.first.to_s.strip
      pid.empty? ? '%0' : pid
    end

    def tmux_send_key(session, pane, key)
      target = "#{session}:0.0"
      target = "#{session}:#{pane}" if pane && !pane.empty? && pane != '%0'
      case key
      when 'Enter','ENTER'      then run_capture(%(#{TMUX} send-keys -t #{target.shellescape} Enter))
      when 'C-c','CTRL_C'       then run_capture(%(#{TMUX} send-keys -t #{target.shellescape} C-c))
      when 'Tab','TAB'          then run_capture(%(#{TMUX} send-keys -t #{target.shellescape} Tab))
      else                           run_capture(%(#{TMUX} send-keys -t #{target.shellescape} #{key}))
      end
    end

    def tmux_send_text(session, pane, text)
      target = "#{session}:0.0"
      target = "#{session}:#{pane}" if pane && !pane.empty? && pane != '%0'
      run_capture(%(#{TMUX} send-keys -t #{target.shellescape} -- #{text.shellescape}))
    end

    def tmux_capture(session, pane)
      target = "#{session}:0.0"
      target = "#{session}:#{pane}" if pane && !pane.empty? && pane != '%0'
      run_capture(%(#{TMUX} capture-pane -p -J -S -2000 -t #{target.shellescape}))
    end

    def tmux_interrupt(session)
      tmux_send_key(session, nil, 'C-c')
    end

    def tmux_wait_dead(session, timeout_s: 5)
      Timeout.timeout(timeout_s) do
        loop do
          return true unless tmux_alive?(session)
          sleep 0.2
        end
      end
    rescue Timeout::Error
      false
    end
  end
end
