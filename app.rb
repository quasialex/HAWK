# app.rb
require 'yaml'
require 'json'
require 'sinatra/base'
require 'sinatra/reloader' if ENV['RACK_ENV'] == 'development'
require 'sinatra/json'
require_relative 'core/exec'
require_relative 'core/module_base'
require_relative 'core/registry'
require_relative 'core/ui_helpers'

Dir[File.join(__dir__, 'modules', '**', '*.rb')].sort.each { |f| require f }

class HackberryApp < Sinatra::Base
  set :bind, '0.0.0.0'
  set :port, 4567
  set :public_folder, File.expand_path('public', __dir__)
  set :views, File.expand_path('views', __dir__)
  enable :method_override

  helpers do
    include Hackberry::UIHelpers
  end

  CONFIG_PATH = File.join(__dir__, 'config', 'config.yml')
  CONFIG = YAML.load_file(CONFIG_PATH)['defaults']

  before do
    Hackberry::Exec.ensure_dirs(CONFIG)
  end

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
    erb :module
  end

  post '/run/:id/:action' do
    mod = Hackberry::Registry.find(params[:id]) or halt 404
    action_id = params[:action]
    action = mod.actions.find { |a| a[:id] == action_id } or halt 400, 'Bad action'
    inputs = action[:inputs].map { |i| [i[:name], params[i[:name]]] }.to_h
    @result = mod.run(action_id, inputs, CONFIG)
    erb :run
  end

  # === Status ===
  get '/status' do
    @sessions = Hackberry::Exec.tmux_list
    erb :status
  end

  delete '/status/:session' do
    Hackberry::Exec.tmux_kill(params[:session])
    redirect '/status'
  end

  # === Logs ===
  get '/logs' do
    @logs = Dir.glob(File.join(CONFIG['paths']['logs'], '*.log')).sort.reverse
    erb :run
  end

  # === Config UI ===
  get '/config' do
    @cfg = CONFIG
    erb :config
  end

  post '/config' do
    CONFIG['interfaces']['wifi'] = params['wifi'] if params['wifi']
    CONFIG['interfaces']['wifi_mon'] = params['wifi_mon'] if params['wifi_mon']
    CONFIG['interfaces']['ble'] = params['ble'] if params['ble']
    CONFIG['interfaces']['lan'] = params['lan'] if params['lan']
    File.write(CONFIG_PATH, { 'defaults' => CONFIG }.to_yaml)
    redirect '/config'
  end
end

HackberryApp.run! if $0 == __FILE__
