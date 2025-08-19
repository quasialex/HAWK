# routes/tty.rb
require 'shellwords'
require_relative '../core/exec'

class HackberryApp < Sinatra::Base
  # List sessions / create new shell
  get '/tty' do
    @sessions = Hackberry::Exec.tmux_list
    erb :tty
  end

  post '/tty/new' do
    s = Hackberry::Exec.tmux_new_shell(name: 'tty')
    redirect "/tty/#{s}"
  end

  # Terminal page
  get '/tty/:session' do
    @session = params[:session]
    halt 404, "No such session" unless Hackberry::Exec.tmux_list.include?(@session)
    erb :tty
  end

  # Simple polling snapshot (entire pane content)
  get '/tty/:session/snap' do
    content_type 'text/plain'
    s = params[:session]
    halt 404 unless Hackberry::Exec.tmux_list.include?(s)
    `tmux capture-pane -p -J -S -2000 -t #{Shellwords.escape(s)}:0.0 2>/dev/null` || ""
  end

  # Send text/keys
  post '/tty/:session/send' do
    s = params[:session]
    halt 404 unless Hackberry::Exec.tmux_list.include?(s)

    key  = params['key'].to_s
    text = params['text'].to_s

    if !text.empty?
      system(%(tmux send-keys -t #{Shellwords.escape(s)}:0.0 -- #{text.shellescape}))
      system(%(tmux send-keys -t #{Shellwords.escape(s)}:0.0 Enter))
    else
      case key
      when 'ENTER'  then system(%(tmux send-keys -t #{Shellwords.escape(s)}:0.0 Enter))
      when 'CTRL_C' then Hackberry::Exec.tmux_interrupt(s)
      when 'TAB'    then system(%(tmux send-keys -t #{Shellwords.escape(s)}:0.0 Tab))
      end
    end
    status 204
  end

  # Stop the terminal session (Ctrl‑C → kill)
  post '/tty/:session/stop' do
    s = params[:session]
    Hackberry::Exec.tmux_interrupt(s)
    Hackberry::Exec.tmux_wait_dead(s, timeout_s: 3)
    Hackberry::Exec.tmux_kill(s) if Hackberry::Exec.tmux_alive?(s)
    redirect '/tty'
  end
end
