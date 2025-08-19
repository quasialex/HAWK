# core/exec.rb
require 'open3'
require 'fileutils'
require 'shellwords'
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

    def sh_with_env(inner)
      %(bash -lc 'export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"; #{inner}')
    end

    # --- tmux helpers ---

    def tmux_run(name:, cmd:, log_path:)
      session = "#{name}-#{timestamp}"
      FileUtils.mkdir_p File.dirname(log_path)
      full = %(tmux new-session -d -s #{session.shellescape} #{sh_with_env(%Q{"#{cmd.gsub('"','\\"')}" 2>&1 | tee -a #{log_path.shellescape}})})
      system(full)
      { session: session, cmd: cmd, log: log_path }
    end

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

    # Interactive shell (no tee) for the web terminal
    def tmux_new_shell(name: 'tty')
      session = "#{name}-#{timestamp}"
      full = %(tmux new-session -d -s #{session.shellescape} #{sh_with_env(%Q{"bash --login -i"})})
      system(full)
      session
    end

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

    def tmux_interrupt(session)
      run_capture(%(tmux send-keys -t #{session.shellescape}:0.0 C-c))
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

    def tmux_kill(session)
      run_capture(%(tmux kill-session -t #{session.shellescape}))
    end
  end
end
