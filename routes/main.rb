# frozen_string_literal: true
require "sinatra"

get "/modules/:key" do
  klass = Registry.find(params[:key])
  halt 404, "No module #{params[:key]}" unless klass
  @mod = klass
  @last = Profiles.last(@mod.key)
  erb :module
end

post "/modules/:key/run" do
  klass = Registry.find(params[:key])
  halt 404, "No module #{params[:key]}" unless klass
  logfile = klass.run(params)
  redirect to("/run?log=#{File.basename(logfile)}")
end

get "/run" do
  @logfile = params[:log]
  halt 400, "missing log param" unless @logfile
  erb :run
end
