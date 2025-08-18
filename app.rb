# app.rb
require 'yaml'
require 'json'
require 'sinatra/base'
require_relative 'core/exec'
require_relative 'core/module_base'
require_relative 'core/registry'
require_relative 'core/ui_helpers'

# Autoload modules
Dir[File.join(__dir__, 'modules', '**', '*.rb')].sort.each { |f| require f }

class HackberryApp < Sinatra::Base
  set :bind, '0.0.0.0'
  set :port, 4567
  set :public_folder, File.expand_path('public', __dir__)
  set :views, File.expand_path('views', __dir__)

  helpers do
    include Hackberry::UIHelpers
  end

  CONFIG = YAML.load_file(File.join(__dir__, 'config', 'config.yml'))['defaults']

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
    # Extract only inputs defined by the action
    action = mod.actions.find { |a| a[:id] == action_id }
    halt 400, 'Bad action' unless action
    inputs = action[:inputs].map { |i| [i[:name], params[i[:name]]] }.to_h
    result = mod.run(action_id, inputs, CONFIG)
    @result = result
    erb :run
  end

  get '/logs' do
    @logs = Dir.glob(File.join(CONFIG['paths']['logs'], '*.log')).sort.reverse
    erb :run
  end
end

HackberryApp.run! if $0 == __FILE__
