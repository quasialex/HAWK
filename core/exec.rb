# core/exec.rb
require 'open3'
require 'fileutils'
require 'shellwords'
require 'timeout'

module Hackberry
  module Exec
    module_function

    # --- filesystem helpers ---------------------------------------------------

    def ensure_dirs(cfg)
      FileUtils.mkdir_p cfg['paths']['logs']
      FileUtils.mkdir_p cfg['paths']['captures']
      FileUtils.mkdir_p cfg['paths']['caplets'] if cfg['paths']['caplets']
    end

    def timestamp
      Time.now.utc.strftime('%Y%m%d-%H%M%S')
    end

    # --- shell helpers --------------------------------------------------------

    # Capture a one-off command's output
    def run_capture(cmd)
      stdout, stderr, status = Open3.capture3({'LC_ALL'=>'C'}, cmd)
      { out: stdout, err: stderr, code: status.exitstatus }
    end

    # Wrap a command in a login shell with a sane PATH (so /usr/sbin etc. are found)
    def sh_with_env(inner)
      %(bash -lc 'export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"; #{inner}')
    end

    # --- tmux helpers ---------------------------------------------------------

    # Start a detached tmux session running a single command, teeing to log.
    # Returns: { session:, cmd:, log: }
    #
    # NOTE: Always creates a unique session name: "#{name}-#{timestamp}"
    # to avoid collisions—same shape as older versions.
    def tmux_run(name:, cmd:, log_path:)
      session = "#{name}-#{timestamp}"
      FileUtils.mkdir_p File.dirname(log_path)
      full = %(tmux new-session -d -s #{session.shellescape} #{sh_with_env(%Q{"#{cmd.gsub('"','\\"')}" 2>&1 | tee -a #{log_path.shellescape}})})
      system(full)
      { session: session, cmd: cmd, log: log_path }
    end

    # Like tmux_run, but runs a multi-line script file we write to /tmp.
    def tmux_run_script(name:, content:, log_path:)
      session = "#{name}-#{timestamp}"
      FileUtils.mkdir_p File.dirname(log_path)
      script  = File.join('/tmp', "hawk_#{name}_#{timestamp}.sh")
      File.write(script, content)
      File.chmod(0755, script)
      full = %(tmux new-session -d -s #{session.shellescape} #{sh_with_env(%Q{"/bin/bash #{script.shellescape} 2>&1 | tee -a #{log_path.shellescape}"})})
      system(full)
      { session: session, cmd: "/bin/bash #{script}", log: log_path, script: script }
    end

    # List all tmux sessions (names only). When tmux isn't running, returns [].
    def tmux_list(prefix: nil)
      out = run_capture('tmux ls')
      return [] unless out[:code] == 0
      sessions = out[:out].split("\n").map { |l| l.split(':').first }
      return sessions if prefix.nil? || prefix.empty?
      sessions.grep(/^#{Regexp.escape(prefix)}/)
    end

    def tmux_alive?(session)
      tmux_list.include?(session)
    end

    # Send a Ctrl-C to the first pane of the session (graceful stop)
    def tmux_interrupt(session)
      run_capture(%(tmux send-keys -t #{session.shellescape}:0.0 C-c))
    end

    # Wait up to timeout_s for the session to be gone. Returns true if gone.
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

    # Hard kill a session (fallback after interrupt/wait)
    def tmux_kill(session)
      run_capture(%(tmux kill-session -t #{session.shellescape}))
    end
  end
end
