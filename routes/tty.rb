# routes/tty.rb
require 'sinatra/streaming'
require_relative '../core/exec'

class HackberryApp < Sinatra::Base
  helpers Sinatra::Streaming

  # TTY landing: list tmux sessions and quick "new shell" button
  get '/tty' do
    @sessions = Hackberry::Exec.tmux_list
    erb :tty
  end

  # Create a fresh interactive shell session in tmux
  post '/tty/new' do
    base = "tty"
    session = "#{base}-#{Hackberry::Exec.timestamp}"
    log = File.join(HackberryApp::CONFIG['paths']['logs'], "tty-#{Hackberry::Exec.timestamp}.log")
    # Start an interactive login shell; use a plain pane we can send keys to
    cmd = "script -q -c bash /dev/null"
    Hackberry::Exec.tmux_run(name: session, cmd: cmd, log_path: log)
    redirect "/tty/#{session}"
  end

  # Terminal page
  get '/tty/:session' do
    @session = params[:session]
    halt 404, "No such session" unless Hackberry::Exec.tmux_list.include?(@session)
    erb :tty
  end

  # SSE stream of pane contents (simple polling of capture-pane)
  get '/tty/:session/stream' do
    content_type 'text/event-stream'
    session = params[:session]
    halt 404 unless Hackberry::Exec.tmux_list.include?(session)

    last = ""
    stream(:keep_open) do |out|
      begin
        loop do
          # Capture last 2000 characters with join-lines (-J)
          cap = `tmux capture-pane -p -J -t "#{session}:0.0" -S -2000 2>/dev/null`
          if cap && cap != last
            # Send only the delta to cut bandwidth
            delta = cap[last.length..-1] || cap
            out << "data: #{delta.gsub(/\r?\n/, "\n")}\n\n"
            last = cap
          end
          sleep 0.5
        end
      rescue => e
        out << "event: error\n" << "data: #{e.class}: #{e.message}\n\n"
      ensure
        out.close
      end
    end
  end

  # Send keys / text to the tmux pane
  post '/tty/:session/send' do
    s = params[:session]
    halt 404 unless Hackberry::Exec.tmux_list.include?(s)

    key = params['key'].to_s
    text = params['text'].to_s

    if !text.empty?
      system(%(tmux send-keys -t "#{s}:0.0" -- #{text.shellescape}))
    elsif key == 'ENTER'
      system(%(tmux send-keys -t "#{s}:0.0" Enter))
    elsif key == 'CTRL_C'
      Hackberry::Exec.tmux_interrupt(s)
    elsif key == 'TAB'
      system(%(tmux send-keys -t "#{s}:0.0" Tab))
    end

    status 204
  end

  # Kill the tty session (Ctrl‑C + kill fallback)
  post '/tty/:session/stop' do
    s = params[:session]
    Hackberry::Exec.tmux_interrupt(s)
    Hackberry::Exec.tmux_wait_dead(s, timeout_s: 3)
    Hackberry::Exec.tmux_kill(s) if Hackberry::Exec.tmux_alive?(s)
    redirect '/tty'
  end
end
