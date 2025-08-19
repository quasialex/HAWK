# app.rb
require 'yaml'
require 'json'
require 'sinatra/base'
require 'sinatra/json'
require 'sinatra/streaming'   # + live SSE
require_relative 'core/exec'
require_relative 'core/module_base'
require_relative 'core/registry'
require_relative 'core/ui_helpers'
require_relative 'core/ifaces'
require_relative 'core/profiles'
require_relative 'core/tasks'  # + tasks index (data/tasks.json)

# Autoload modules
Dir[File.join(__dir__, 'modules', '**', '*.rb')].sort.each { |f| require f }

class HackberryApp < Sinatra::Base
  helpers Sinatra::Streaming
  set :bind, '0.0.0.0'
  set :port, 4567
  set :public_folder, File.expand_path('public', __dir__)
  set :views, File.expand_path('views', __dir__)
  enable :method_override

  helpers do
    include Hackberry::UIHelpers
  end

  CONFIG_PATH = File.join(__dir__, 'config', 'config.yml')
  CONFIG   = YAML.load_file(CONFIG_PATH)['defaults']
  PROFILES = Hackberry::Profiles.new(File.join(__dir__, 'data', 'profiles.json'))
  TASKS    = Hackberry::Tasks.new(File.join(__dir__, 'data', 'tasks.json'))

  before { Hackberry::Exec.ensure_dirs(CONFIG) }

  # ===== Home & Categories =====
  get '/' do
    @by_cat = Hackberry::Registry.by_category
    erb :index
  end

  get '/category/:cat' do
    @cat = params[:cat].to_sym
    @mods = Hackberry::Registry.mods.select { |m| m.category == @cat }
    halt 404, 'Category not found' if @mods.empty?
    erb :category
  end

  # ===== Module page (with autodetect + profiles + running sessions for STOP) =====
  get '/module/:id' do
    @mod = Hackberry::Registry.find(params[:id]) or halt 404

    # deep dup + inject dropdowns + profile defaults
    @actions = Marshal.load(Marshal.dump(@mod.actions))
    wifi = Hackberry::Ifaces.names(Hackberry::Ifaces.wifi)
    wmon = Hackberry::Ifaces.names(Hackberry::Ifaces.wifi_mon)
    lan  = Hackberry::Ifaces.names(Hackberry::Ifaces.lan)
    ble  = Hackberry::Ifaces.ble

    @actions.each do |a|
      last = PROFILES.get(@mod.id, a[:id])
      a[:inputs].each do |i|
        # last-used defaults
        i[:default] = last[i[:name]] if last[i[:name]] && (i[:default].nil? || i[:default].to_s.empty?)
        # infer dropdowns
        name = i[:name]; ph = (i[:placeholder] || '').downcase
        if (name =~ /iface/ && ph.include?('wlan')) || name == 'iface_wifi'
          i[:type] = 'select'; i[:options] = wifi
        elsif (name =~ /iface/ && ph.include?('mon')) || name == 'iface_mon'
          i[:type] = 'select'; i[:options] = wmon.empty? ? wifi : wmon
        elsif (name =~ /iface/ && ph.include?('eth')) || name == 'iface_lan'
          i[:type] = 'select'; i[:options] = lan
        elsif ph.include?('hci') || name == 'iface_ble'
          i[:type] = 'select'; i[:options] = ble
        end
      end
    end

    # show running sessions for this module (from TASKS index)
    @running = Hackberry::Exec.tmux_list(prefix: nil).filter_map { |s|
      t = TASKS.find(s)
      t if t && t['module_id'] == @mod.id
    }

    erb :module
  end

  # ===== Run action -> record a TASK -> redirect to Tasks (Live) =====
  post '/run/:id/:action' do
    mod = Hackberry::Registry.find(params[:id]) or halt 404
    action_id = params[:action]
    action = mod.actions.find { |a| a[:id] == action_id } or halt 400, 'Bad action'

    inputs = action[:inputs].map { |i| [i[:name], params[i[:name]]] }.to_h
    PROFILES.set(mod.id, action_id, inputs)

    result = mod.run(action_id, inputs, CONFIG)
    if result && result[:session]
      TASKS.add({
        'session'   => result[:session],
        'module_id' => mod.id,
        'action'    => action_id,
        'cmd'       => result[:cmd],
        'log'       => File.basename(result[:log].to_s),
        'started'   => Time.now.utc.iso8601,
        'status'    => 'running'
      })
      redirect "/tasks?session=#{result[:session]}"
    else
      # fallback to the old run page if a module returns no session
      @result = result
      erb :run
    end
  end

  # ===== Status (raw tmux list/kill) =====
  get '/status' do
    @sessions = Hackberry::Exec.tmux_list
    erb :status
  end

  delete '/status/:session' do
    Hackberry::Exec.tmux_kill(params[:session])
    TASKS.update_status!(params[:session], 'stopped')
    redirect '/status'
  end

  # ===== Tasks manager (preview/live/stop) =====
  get '/tasks' do
    @tasks     = TASKS.all
    @highlight = params['session']
    @mods_map  = Hash[Hackberry::Registry.mods.map { |m| [m.id, m] }]
    erb :tasks
  end

  post '/tasks/:session/stop' do
    s = params[:session]
    Hackberry::Exec.tmux_kill(s)
    TASKS.update_status!(s, 'stopped')
    redirect '/tasks'
  end

  # ===== Logs =====
  get '/logs' do
    @logs = Dir.glob(File.join(CONFIG['paths']['logs'], '*.log')).sort.reverse
    erb :run
  end

  # Simple preview (existing behavior)
  get '/log' do
    file = params['file'] or halt 400
    path = File.join(CONFIG['paths']['logs'], File.basename(file))
    halt 404 unless File.exist?(path)
    @file = File.basename(path)
    @content = File.readlines(path).last(200).join
    erb :log_view
  end

  # Live SSE stream (by session or by file)
  get '/stream' do
    content_type 'text/event-stream'
    log = params['log']
    if (sess = params['session'])
      task = TASKS.find(sess) or halt 404
      log = task['log']
    end
    halt 400 unless log
    path = File.join(CONFIG['paths']['logs'], File.basename(log))
    halt 404 unless File.exist?(path)

    stream(:keep_open) do |out|
      begin
        out << "event: open\n" << "data: streaming #{File.basename(path)}\n\n"
        pos = 0
        File.open(path, 'r') do |f|
          buf = f.read
          if buf
            buf.each_line { |line| out << "data: #{line.rstrip}\n\n" }
            pos = f.pos
          end
          loop do
            sleep 1
            f.seek(pos)
            chunk = f.read
            next unless chunk
            chunk.each_line { |line| out << "data: #{line.rstrip}\n\n" }
            pos = f.pos
          end
        end
      rescue => e
        out << "event: error\n" << "data: #{e.class}: #{e.message}\n\n"
      ensure
        out.close
      end
    end
  end

  # ===== Config =====
  get '/config' do
    @cfg = CONFIG
    erb :config
  end

  post '/config' do
    %w[wifi wifi_mon ble lan].each { |k| CONFIG['interfaces'][k] = params[k] if params[k] }
    File.write(CONFIG_PATH, { 'defaults' => CONFIG }.to_yaml)
    redirect '/config'
  end

  # ===== Bettercap Caplets (editor + runner) =====
  get '/caplets' do
    dir = CONFIG['paths']['caplets']
    Dir.mkdir(dir) unless Dir.exist?(dir)
    @cfg  = CONFIG  # for editor template that reads file
    @caps = Dir.glob(File.join(dir, '*.cap')).map { |p| File.basename(p) }
    erb :caplets
  end

  post '/caplets/new' do
    dir = CONFIG['paths']['caplets']
    Dir.mkdir(dir) unless Dir.exist?(dir)
    name = params['name'].to_s.gsub(/[^a-zA-Z0-9_\-]/,'_')
    halt 400, 'bad name' if name.empty?
    path = File.join(dir, name + '.cap')
    File.write(path, "# bettercap caplet\n") unless File.exist?(path)
    redirect "/caplets?edit=#{File.basename(path)}"
  end

  post '/caplets/save' do
    dir = CONFIG['paths']['caplets']
    path = File.join(dir, File.basename(params['file']))
    File.write(path, params['content'] || '')
    redirect "/caplets?edit=#{File.basename(path)}"
  end

  post '/caplets/run' do
    dir = CONFIG['paths']['caplets']
    file = File.join(dir, File.basename(params['file']))
    halt 404 unless File.exist?(file)
    log = File.join(CONFIG['paths']['logs'], "caplet-#{Hackberry::Exec.timestamp}.log")
    res = Hackberry::Exec.tmux_run(name:'bettercap-caplet', cmd:"bettercap -caplet #{file}", log_path: log)
    TASKS.add({
      'session'   => res[:session],
      'module_id' => 'wifi_caplet',
      'action'    => 'run',
      'cmd'       => res[:cmd],
      'log'       => File.basename(res[:log]),
      'started'   => Time.now.utc.iso8601,
      'status'    => 'running'
    })
    redirect "/tasks?session=#{res[:session]}"
  end

  # ===== MSF RPC module search (autocomplete) =====
  get '/api/msf/search' do
    begin
      require 'msfrpc-client'
      host = params['host'] || '127.0.0.1'
      port = (params['port'] || '55553').to_i
      user = params['user'] || 'msf'
      pass = params['pass'] || 'msf'
      q    = params['q']    || ''
      c = Msf::RPC::Client.new(host: host, port: port, ssl: false)
      c.login(user, pass)
      res = c.call('module.search', q)
      json res.map { |m| m['fullname'] }[0, 50]
    rescue => e
      status 500
      json({ error: e.message })
    end
  end
end

HackberryApp.run! if $0 == __FILE__
