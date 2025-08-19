# core/tty.rb
require 'pty'
require 'io/console'
require 'securerandom'
require 'fileutils'
require 'thread'

module Hackberry
  module TTY
    Session = Struct.new(:id, :master, :slave, :pid, :buf, :mutex, :log, keyword_init: true)

    @sessions = {}
    @lock = Mutex.new

    class << self
      # Create a login shell with a proper PTY. Returns the session id.
      def create(log_dir:)
        FileUtils.mkdir_p(log_dir)
        id  = "pty-#{SecureRandom.hex(6)}"
        log = File.join(log_dir, "#{id}.log")

        # Ensure logs exist immediately
        FileUtils.touch(log)

        env = {
          'TERM'  => 'xterm-256color',
          'LC_ALL'=> 'C',
          'PATH'  => '/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin'
        }

        master, slave, pid = PTY.spawn(env, '/bin/bash', '--login', '-i')

        sess = Session.new(
          id:    id,
          master: master,
          slave:  slave,
          pid:    pid,
          buf:    String.new(capacity: 131072),
          mutex:  Mutex.new,
          log:    log
        )

        # Reader thread: copy PTY -> ring buffer & log file
        Thread.new do
          File.open(log, 'a') do |f|
            begin
              loop do
                data = master.readpartial(4096)
                sess.mutex.synchronize do
                  sess.buf << data
                  # keep last ~200KB
                  sess.buf = sess.buf[-200_000, 200_000] || sess.buf
                end
                f.write(data)
                f.flush
              end
            rescue EOFError, Errno::EIO
              # shell exited
            rescue => e
              f.puts "\n[HAWK TTY ERROR] #{e.class}: #{e.message}\n"
              f.flush
            ensure
              begin master.close unless master.closed?; rescue; end
              begin slave.close  unless slave.closed?;  rescue; end
            end
          end
        end

        # Friendly banner
        write(id, "echo '[HAWK TTY] #{Time.now.utc}'; pwd; whoami; echo $SHELL\n")

        @lock.synchronize { @sessions[id] = sess }
        id
      end

      # Write raw text to the shell (append newline yourself if you want Enter)
      def write(id, text)
        sess = @lock.synchronize { @sessions[id] }
        return false unless sess
        sess.master.write(text)
        true
      rescue Errno::EIO, IOError
        false
      end

      # Convenience: send Enter / Ctrl-C / Tab
      def send_key(id, key)
        case key
        when :enter then write(id, "\n")
        when :ctrl_c then write(id, "\u0003")
        when :tab    then write(id, "\t")
        else false
        end
      end

      # Snapshot last N bytes from the ring buffer
      def snapshot(id, bytes: 2000)
        sess = @lock.synchronize { @sessions[id] }
        return "" unless sess
        sess.mutex.synchronize do
          s = sess.buf
          s = s[-bytes, bytes] || s
          s.dup
        end
      end

      # Stop shell process
      def stop(id)
        sess = @lock.synchronize { @sessions[id] }
        return unless sess
        begin
          Process.kill('INT', sess.pid) rescue nil
          Timeout.timeout(2) { Process.wait(sess.pid) rescue nil } rescue Timeout::Error
          Process.kill('KILL', sess.pid) rescue nil
        ensure
          begin sess.master.close unless sess.master.closed?; rescue; end
          begin sess.slave.close  unless sess.slave.closed?;  rescue; end
          @lock.synchronize { @sessions.delete(id) }
        end
      end

      def list
        @lock.synchronize { @sessions.keys.dup }
      end
    end
  end
end
