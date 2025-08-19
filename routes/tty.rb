# routes/tty.rb
require 'shellwords'
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

  # Terminal page
  get '/tty/:session' do
    @session = params[:session]
    halt 404, "No such session" unless Hackberry::Exec.tmux_list.include?(@session)
    erb :tty
  end

  # Snapshot (returns plain text or a one-line error)
  get '/tty/:session/snap' do
    content_type 'text/plain'
    s = params[:session]
    halt 404 unless Hackberry::Exec.tmux_list.include?(s)
    pane = Hackberry::Exec.tmux_active_pane(s)
    cap  = Hackberry::Exec.tmux_capture(s, pane)
    if cap[:code] == 0
      cap[:out]
    else
      "ERROR: tmux capture failed (code=#{cap[:code]}): #{cap[:err]}".strip
    end
  end

  # Send
  post '/tty/:session/send' do
    s = params[:session]
    halt 404 unless Hackberry::Exec.tmux_list.include?(s)
    pane = Hackberry::Exec.tmux_active_pane(s)

    key  = params['key'].to_s
    text = params['text'].to_s

    if !text.empty?
      Hackberry::Exec.tmux_send_text(s, pane, text)
      Hackberry::Exec.tmux_send_key(s, pane, 'Enter')
    else
      case key
      when 'ENTER'   then Hackberry::Exec.tmux_send_key(s, pane, 'Enter')
      when 'CTRL_C'  then Hackberry::Exec.tmux_send_key(s, pane, 'C-c')
      when 'TAB'     then Hackberry::Exec.tmux_send_key(s, pane, 'Tab')
      end
    end
    status 204
  end

  # Stop
  post '/tty/:session/stop' do
    s = params[:session]
    Hackberry::Exec.tmux_interrupt(s)
    Hackberry::Exec.tmux_wait_dead(s, timeout_s: 3)
    Hackberry::Exec.tmux_kill(s) if Hackberry::Exec.tmux_alive?(s)
    redirect '/tty'
  end

  # Debug info (pane/window list)
  get '/tty/:session/debug' do
    content_type 'text/plain'
    s = params[:session]
    halt 404 unless Hackberry::Exec.tmux_list.include?(s)
    out1 = Hackberry::Exec.run_capture(%(tmux list-windows -a -F '#{session_name}:#{window_index} #{window_active} #{window_name}')).values_at(:out,:err,:code)
    out2 = Hackberry::Exec.run_capture(%(tmux list-panes -a -F '#{session_name}:#{window_index}.#{pane_index} #{pane_id} #{pane_active}')).values_at(:out,:err,:code)
    "WINDOWS:\n#{out1[0]}\nPANES:\n#{out2[0]}"
  end
end
