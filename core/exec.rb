# core/exec.rb
require 'open3'
require 'fileutils'
require 'timeout'

module Hackberry
  module Exec
    module_function

    def ensure_dirs(cfg)
      FileUtils.mkdir_p cfg['paths']['logs']
      FileUtils.mkdir_p cfg['paths']['captures']
      FileUtils.mkdir_p cfg['paths']['caplets'] if cfg['paths']['caplets']
    end

    def timestamp
      Time.now.utc.strftime('%Y%m%d-%H%M%S')
    end

    def run_capture(cmd)
      stdout, stderr, status = Open3.capture3({'LC_ALL'=>'C'}, cmd)
      { out: stdout, err: stderr, code: status.exitstatus }
    end

    def tmux_list(prefix: nil)
      out = run_capture('tmux ls')
      return [] unless out[:code] == 0
      sessions = out[:out].split("\n").map { |l| l.split(':').first }
      return sessions if prefix.nil? || prefix.empty?
      sessions.grep(/^#{Regexp.escape(prefix)}/)
    end

    def tmux_kill(session)
      run_capture(%(tmux kill-session -t "#{session}"))
    end

    # Send Ctrl-C to the session's first pane
    def tmux_interrupt(session)
      run_capture(%(tmux send-keys -t "#{session}:0.0" C-c))
    end

    def tmux_alive?(session)
      tmux_list.include?(session)
    end

    # Wait until tmux reports the session dead (or timeout)
    def tmux_wait_dead(session, timeout_s: 5)
      Timeout.timeout(timeout_s) do
        loop do
          break unless tmux_alive?(session)
          sleep 0.2
        end
      end
    rescue Timeout::Error
      false
    end

    # Compose a shell that sets a robust PATH, then runs the command
    def sh_with_env(inner)
      %(bash -lc 'export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"; #{inner}')
    end

    # One-liner commands
    def tmux_run(name:, cmd:, log_path:)
      session = "#{name}-#{timestamp}"
      FileUtils.mkdir_p File.dirname(log_path)
      full = %(tmux new-session -d -s "#{session}" "#{sh_with_env("#{cmd} 2>&1 | tee -a #{log_path}")}")
      system(full)
      { session: session, cmd: cmd, log: log_path }
    end

    # Multi-line script
    def tmux_run_script(name:, content:, log_path:)
      session = "#{name}-#{timestamp}"
      FileUtils.mkdir_p File.dirname(log_path)
      script  = File.join('/tmp', "hawk_#{name}_#{timestamp}.sh")
      File.write(script, content)
      File.chmod(0755, script)
      full = %(tmux new-session -d -s "#{session}" "#{sh_with_env("/bin/bash #{script} 2>&1 | tee -a #{log_path}")}")
      system(full)
      { session: session, cmd: "/bin/bash #{script}", log: log_path, script: script }
    end
  end
end
