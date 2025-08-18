# app.rb
require 'yaml'
require 'json'
require 'sinatra/base'
require 'sinatra/json'
require_relative 'core/exec'
require_relative 'core/module_base'
require_relative 'core/registry'
require_relative 'core/ui_helpers'
require_relative 'core/ifaces'
require_relative 'core/profiles'

Dir[File.join(__dir__, 'modules', '**', '*.rb')].sort.each { |f| require f }

class HackberryApp < Sinatra::Base
  set :bind, '0.0.0.0'
  set :port, 4567
  set :public_folder, File.expand_path('public', __dir__)
  set :views, File.expand_path('views', __dir__)
  enable :method_override

  helpers { include Hackberry::UIHelpers }

  CONFIG_PATH = File.join(__dir__, 'config', 'config.yml')
  CONFIG = YAML.load_file(CONFIG_PATH)['defaults']
  PROFILES = Hackberry::Profiles.new(File.join(__dir__, 'data', 'profiles.json'))

  before { Hackberry::Exec.ensure_dirs(CONFIG) }

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

  get '/module/:id' do
    @mod = Hackberry::Registry.find(params[:id]) or halt 404
    # deep dup actions and inject select options based on input names
    @actions = Marshal.load(Marshal.dump(@mod.actions))

    wifi = Hackberry::Ifaces.names(Hackberry::Ifaces.wifi)
    wmon = Hackberry::Ifaces.names(Hackberry::Ifaces.wifi_mon)
    lan  = Hackberry::Ifaces.names(Hackberry::Ifaces.lan)
    ble  = Hackberry::Ifaces.ble

    @actions.each do |a|
      last = PROFILES.get(@mod.id, a[:id])
      a[:inputs].each do |i|
        # auto fill defaults from profile
        if last[i[:name]] && (i[:default].nil? || i[:default].to_s.empty?)
          i[:default] = last[i[:name]]
        end
        # infer dropdowns
        name = i[:name]
        ph   = (i[:placeholder] || '').downcase
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

    erb :module
  end

  post '/run/:id/:action' do
    mod = Hackberry::Registry.find(params[:id]) or halt 404
    action_id = params[:action]
    action = mod.actions.find { |a| a[:id] == action_id } or halt 400, 'Bad action'
    inputs = action[:inputs].map { |i| [i[:name], params[i[:name]]] }.to_h
    PROFILES.set(mod.id, action_id, inputs) # auto-save last used
    @result = mod.run(action_id, inputs, CONFIG)
    erb :run
  end

  # Status (tmux)
  get '/status' do
    @sessions = Hackberry::Exec.tmux_list
    erb :status
  end
  delete '/status/:session' do
    Hackberry::Exec.tmux_kill(params[:session]); redirect '/status'
  end

  # Logs list
  get '/logs' do
    @logs = Dir.glob(File.join(CONFIG['paths']['logs'], '*.log')).sort.reverse
    erb :run
  end

  # Live log tail
  get '/log' do
    file = params['file'] or halt 400
    path = File.join(CONFIG['paths']['logs'], File.basename(file))
    halt 404 unless File.exist?(path)
    @file = File.basename(path)
    @content = File.readlines(path).last(200).join
    erb :log_view
  end

  # Config
  get '/config' do
    @cfg = CONFIG; erb :config
  end
  post '/config' do
    %w[wifi wifi_mon ble lan].each { |k| CONFIG['interfaces'][k] = params[k] if params[k] }
    File.write(CONFIG_PATH, { 'defaults' => CONFIG }.to_yaml)
    redirect '/config'
  end
end

HackberryApp.run! if $0 == __FILE__
