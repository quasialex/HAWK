# core/exec.rb
require 'open3'
require 'fileutils'
require 'shellwords'
require 'timeout'

module Hackberry
  module Exec
    module_function

    # ---- tmux socket & server management ----
    TMUX_DIR  = ENV['HAWK_TMUX_DIR'] || '/tmp/hawk-tmux'
    TMUX_SOCK = File.join(TMUX_DIR, 'tmux.sock')
    TMUX      = "tmux -S #{Shellwords.escape(TMUX_SOCK)}"  # dedicated tmux server/socket

    def bootstrap_tmux!
      FileUtils.mkdir_p(TMUX_DIR)
      File.chmod(0o777, TMUX_DIR) rescue nil
      # ensure a server exists
      res = run_capture("#{TMUX} has-session")
      unless res[:code] == 0
        run_capture("#{TMUX} start-server")
        run_capture(%(#{TMUX} set-option -g default-shell #{Shellwords.escape(ENV['SHELL'] || '/bin/bash')}))
        run_capture(%(#{TMUX} set-option -g default-terminal screen-256color))
        run_capture(%(#{TMUX} set-option -g mouse on))
      end
    rescue => e
      warn "[hawk] tmux bootstrap failed: #{e}"
    end

    # ---------- dirs / timestamps ----------
    def ensure_dirs(cfg)
      FileUtils.mkdir_p cfg['paths']['logs']
      FileUtils.mkdir_p cfg['paths']['captures']
      FileUtils.mkdir_p cfg['paths']['caplets'] if cfg['paths']['caplets']
    end

    def timestamp
      Time.now.utc.strftime('%Y%m%d-%H%M%S')
    end

    # ---------- shell helpers ----------
    def run_capture(cmd)
      out, err, st = Open3.capture3({'LC_ALL' => 'C', 'LANG' => 'C'}, cmd)
      { out: out, err: err, code: st.exitstatus }
    end

    def run_bg(cmd)
      pid = Process.spawn({'LC_ALL' => 'C', 'LANG' => 'C'}, cmd, [:out, :err] => '/dev/null')
      Process.detach(pid)
      pid
    end

    def touch_log(path)
      FileUtils.mkdir_p File.dirname(path)
      FileUtils.touch(path)
      File.chmod(0644, path) rescue nil
    end

    # ---------- tmux helpers ----------
    def tmux_list
      bootstrap_tmux!
      r = run_capture(%(#{TMUX} list-sessions -F '\#{session_name}'))
      return [] unless r[:code] == 0
      r[:out].split('\n').map(&:strip).reject(&:empty?)
    end

    def tmux_alive?(session)
      bootstrap_tmux!
      r = run_capture(%(#{TMUX} has-session -t #{session.shellescape}))
      r[:code] == 0
    end

    def tmux_kill(session)
      bootstrap_tmux!
      run_capture(%(#{TMUX} kill-session -t #{session.shellescape}))
      true
    end

    def tmux_active_pane(session)
      bootstrap_tmux!
      r = run_capture(%(#{TMUX} display-message -p -t #{session.shellescape} '\#{pane_id}'))
      return nil unless r[:code] == 0
      r[:out].strip
    end

    # Runs a single command under tmux, teeing output to log. Returns {session:, cmd:, log:}
    def tmux_run(name:, cmd:, log_path:)
      bootstrap_tmux!
      session = "#{name}-#{timestamp}"
      touch_log(log_path)
      shell = ENV['SHELL'] || '/bin/bash'
      # create detached login shell
      run_capture(%(#{TMUX} new-session -d -s #{session.shellescape} #{Shellwords.escape(shell)} -l))
      # compose pipeline, then type it and press Enter
      cmd_sq = cmd.gsub("'", %q('"'"'))
      inner  = %Q{set -o pipefail; stdbuf -oL -eL '#{cmd_sq}' 2>&1 | tee -a #{Shellwords.escape(log_path)}}
      run_capture(%(#{TMUX} send-keys -t #{session.shellescape} -l -- #{Shellwords.escape(inner)}))
      run_capture(%(#{TMUX} send-keys -t #{session.shellescape} Enter))
      { session: session, cmd: cmd, log: log_path }
    end

    # New interactive login shell (used by /tty)
    def tmux_new_shell(name: 'tty', cwd: Dir.pwd, log_path: File.join('/tmp', "hawk_#{name}_#{timestamp}.log"))
      bootstrap_tmux!
      session = "#{name}-#{timestamp}"
      touch_log(log_path)
      shell = ENV['SHELL'] || '/bin/bash'
      run_capture(%(#{TMUX} new-session -d -s #{session.shellescape} -c #{Shellwords.escape(cwd)} #{Shellwords.escape(shell)} -l))
      # tee the interactive shell output to log by attaching a pipe pane
      run_capture(%(#{TMUX} pipe-pane -t #{session.shellescape}:0.0 -o 'cat >> #{Shellwords.escape(log_path)}'))
      { session: session, cmd: "#{shell} -l", log: log_path }
    end

    # Runs a multi-line script by writing it to /tmp and executing inside tmux
    def tmux_run_script(name:, content:, log_path:)
      bootstrap_tmux!
      session = "#{name}-#{timestamp}"
      touch_log(log_path)
      script  = File.join('/tmp', "hawk_#{name}_#{timestamp}.sh")
      File.write(script, content)
      File.chmod(0755, script) rescue nil
      shell = ENV['SHELL'] || '/bin/bash'
      run_capture(%(#{TMUX} new-session -d -s #{session.shellescape} #{Shellwords.escape(shell)} -l))
      inner = %Q{set -o pipefail; stdbuf -oL -eL '#{script}' 2>&1 | tee -a #{Shellwords.escape(log_path)}}
      run_capture(%(#{TMUX} send-keys -t #{session.shellescape} -l -- #{Shellwords.escape(inner)}))
      run_capture(%(#{TMUX} send-keys -t #{session.shellescape} Enter))
      { session: session, cmd: script, log: log_path }
    end

    def tmux_send_key(session, pane, key)
      bootstrap_tmux!
      target = "#{session}:0.0"
      target = "#{session}:#{pane}" if pane && !pane.empty? && pane != '%0'
      case key
      when 'Enter','ENTER'      then run_capture(%(#{TMUX} send-keys -t #{target.shellescape} Enter))
      when 'C-c','CTRL_C'       then run_capture(%(#{TMUX} send-keys -t #{target.shellescape} C-c))
      when 'Tab','TAB'          then run_capture(%(#{TMUX} send-keys -t #{target.shellescape} Tab))
      when 'Backspace','BS'     then run_capture(%(#{TMUX} send-keys -t #{target.shellescape} BSpace))
      else
        run_capture(%(#{TMUX} send-keys -t #{target.shellescape} #{key}))
      end
    end

    def tmux_send_text(session, pane, text)
      bootstrap_tmux!
      target = "#{session}:0.0"
      target = "#{session}:#{pane}" if pane && !pane.empty? && pane != '%0'
      run_capture(%(#{TMUX} send-keys -t #{target.shellescape} -l -- #{Shellwords.escape(text)}))
    end

    def tmux_capture(session, pane, lines: 2000)
      bootstrap_tmux!
      target = "#{session}:0.0"
      target = "#{session}:#{pane}" if pane && !pane.empty? && pane != '%0'
      r = run_capture(%(#{TMUX} capture-pane -p -J -S -#{lines} -t #{target.shellescape}))
      return "" unless r[:code] == 0
      r[:out]
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
