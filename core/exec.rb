# core/exec.rb
require 'open3'
require 'fileutils'

module Hackberry
  module Exec
    module_function

    def ensure_dirs(cfg)
      FileUtils.mkdir_p cfg['paths']['logs']
      FileUtils.mkdir_p cfg['paths']['captures']
    end

    def timestamp
      Time.now.utc.strftime('%Y%m%d-%H%M%S')
    end

    # Start a long-running command in tmux so UI can detach.
    def tmux_run(name:, cmd:, log_path:)
      session = "#{name}-#{timestamp}"
      full_cmd = %(tmux new-session -d -s #{session} "bash -lc '#{cmd} |& tee -a #{log_path}'")
      system(full_cmd)
      { session: session, cmd: cmd, log: log_path }
    end

    # Run a short command and capture output.
    def run_capture(cmd)
      stdout, stderr, status = Open3.capture3({'LC_ALL'=>'C'}, cmd)
      { out: stdout, err: stderr, code: status.exitstatus }
    end
  end
end
