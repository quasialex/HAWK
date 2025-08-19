# core/tasks.rb
require 'json'
require 'fileutils'

module Hackberry
  class Tasks
    def initialize(path)
      @path = path
      @data = load
    end

    def load
      JSON.parse(File.read(@path))
    rescue
      []
    end

    def save
      FileUtils.mkdir_p(File.dirname(@path))
      File.write(@path, JSON.pretty_generate(@data))
    end

    def add(rec)
      rec['status'] ||= 'running'
      @data << rec
      save
      rec
    end

    def all
      @data
    end

    def find(session)
      @data.find { |t| t['session'] == session }
    end

    def update_status!(session, status)
      if (t = find(session))
        t['status'] = status
        save
      end
    end

    def remove(session)
      @data.reject! { |t| t['session'] == session }
      save
    end

    # NEW: keep only sessions that are actually alive in tmux AND marked running
    def prune!(alive_sessions)
      before = @data.length
      @data.select! { |t| t['status'] == 'running' && alive_sessions.include?(t['session']) }
      save if @data.length != before
    end

    # NEW: helper to list running tasks against tmux
    def running(alive_sessions)
      @data.select { |t| t['status'] == 'running' && alive_sessions.include?(t['session']) }
    end
  end
end
