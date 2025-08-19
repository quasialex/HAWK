# core/exec.rb
require 'open3'
require 'fileutils'

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

    # Simple one-liner commands
    def tmux_run(name:, cmd:, log_path:)
      session = "#{name}-#{timestamp}"
      FileUtils.mkdir_p File.dirname(log_path)
      full_cmd = %(tmux new-session -d -s #{session} "bash -lc '#{cmd} 2>&1 | tee -a #{log_path}'")
      system(full_cmd)
      { session: session, cmd: cmd, log: log_path }
    end

    # Multi-line scripts (avoids quoting hell)
    def tmux_run_script(name:, content:, log_path:)
      session = "#{name}-#{timestamp}"
      FileUtils.mkdir_p File.dirname(log_path)
      script  = File.join('/tmp', "hawk_#{name}_#{timestamp}.sh")
      File.write(script, content)
      File.chmod(0755, script)
      full_cmd = %(tmux new-session -d -s #{session} "/bin/bash #{script} 2>&1 | tee -a #{log_path}")
      system(full_cmd)
      { session: session, cmd: "/bin/bash #{script}", log: log_path, script: script }
    end

    def tmux_kill(session)
      run_capture("tmux kill-session -t #{session}")
    end
  end
end
