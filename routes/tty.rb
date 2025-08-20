# routes/tty.rb
require_relative '../core/tty'

class HackberryApp < Sinatra::Base
  # Index: list existing PTY sessions
  get '/tty' do
    @sessions = Hackberry::TTY.list
    erb :tty
  end

  # Create a new PTY-backed shell and redirect to it
  post '/tty/new' do
    id = Hackberry::TTY.create(log_dir: CONFIG['paths']['logs'])
    redirect "/tty/#{id}"
  end

  # Render terminal page for given session
  get '/tty/:id' do
    @session = params[:id]
    halt 404, 'No such terminal' unless Hackberry::TTY.list.include?(@session)
    erb :tty
  end

  # Snapshot last bytes of output
  get '/tty/:id/snap' do
    content_type 'text/plain'
    id = params[:id]
    halt 404 unless Hackberry::TTY.list.include?(id)
    out = Hackberry::TTY.snapshot(id, bytes: 4000)
    out.empty? ? "[no output yet]" : out
  end

  # Send text or special keys to the shell
  post '/tty/:id/send' do
    id = params[:id]
    halt 404 unless Hackberry::TTY.list.include?(id)
    if params['text'] && !params['text'].empty?
      Hackberry::TTY.write(id, params['text'])
      Hackberry::TTY.send_key(id, :enter)
    else
      case params['key']
      when 'ENTER'  then Hackberry::TTY.send_key(id, :enter)
      when 'CTRL_C' then Hackberry::TTY.send_key(id, :ctrl_c)
      when 'TAB'    then Hackberry::TTY.send_key(id, :tab)
      end
    end
    status 204
  end

  # Stop session
  post '/tty/:id/stop' do
    id = params[:id]
    Hackberry::TTY.stop(id)
    redirect '/tty'
  end
end
