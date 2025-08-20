# routes/tty.rb (rewritten)
require 'shellwords'
require 'json'
require_relative '../core/exec'

class HackberryApp < Sinatra::Base
  # Index
  get '/tty' do
    @sessions = Hackberry::Exec.tmux_list
    erb :tty
  end

  # New terminal
  post '/tty/new' do
    s = Hackberry::Exec.tmux_new_shell(name: 'tty')
    session = s[:session]
    redirect "/tty/#{session}"
  end

  # Show a terminal page
  get '/tty/:session' do
    @session = params[:session]
    halt 404, "No such session" unless Hackberry::Exec.tmux_alive?(@session)
    erb :tty
  end

  # Poll output (simple polling; returns last N lines)
  get '/tty/:session/poll' do
    content_type 'application/json'
    s = params[:session]
    halt 404, {error: 'no session'}.to_json unless Hackberry::Exec.tmux_alive?(s)
    text = Hackberry::Exec.tmux_capture(s, nil, lines: (params[:lines] || 1500).to_i)
    { session: s, text: text }.to_json
  end

  # Send text
  post '/tty/:session/send' do
    s = params[:session]
    halt 404 unless Hackberry::Exec.tmux_alive?(s)
    if params[:text] && !params[:text].empty?
      Hackberry::Exec.tmux_send_text(s, nil, params[:text].to_s)
      Hackberry::Exec.tmux_send_key(s, nil, 'Enter') if params[:enter] == '1'
    elsif params[:key]
      Hackberry::Exec.tmux_send_key(s, nil, params[:key].to_s)
    end
    status 204
  end

  # Stop terminal
  post '/tty/:session/stop' do
    s = params[:session]
    Hackberry::Exec.tmux_interrupt(s) if Hackberry::Exec.tmux_alive?(s)
    Hackberry::Exec.tmux_wait_dead(s, timeout_s: 3)
    Hackberry::Exec.tmux_kill(s) if Hackberry::Exec.tmux_alive?(s)
    redirect '/tty'
  end

  # Debug info (pane/window list)
  get '/tty/:session/debug' do
    content_type 'text/plain'
    s = params[:session]
    halt 404 unless Hackberry::Exec.tmux_alive?(s)
    out1, _e1, _c1 = Hackberry::Exec.run_capture(%(#{Hackberry::Exec::TMUX} list-windows -a -F '\#{session_name}:\#{window_index} \#{window_active} \#{window_name}'))
    out2, _e2, _c2 = Hackberry::Exec.run_capture(%(#{Hackberry::Exec::TMUX} list-panes -a -F '\#{session_name}:\#{window_index}.\#{pane_index} \#{pane_id} \#{pane_active}'))
    "WINDOWS:\n#{out1}\nPANES:\n#{out2}"
  end
end
