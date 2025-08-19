# core/tasks.rb
require 'json'
require 'fileutils'


module Hackberry
class Tasks
def initialize(path)
@path = path
@data = load
end


def load
JSON.parse(File.read(@path))
rescue
[]
end


def save
FileUtils.mkdir_p(File.dirname(@path))
File.write(@path, JSON.pretty_generate(@data))
end


def add(rec)
@data << rec
save
rec
end


def all
@data
end


def by_mod(mod_id)
@data.select { |t| t['module_id'] == mod_id }
end


def find(session)
@data.find { |t| t['session'] == session }
end


def update_status!(session, status)
if (t = find(session))
t['status'] = status
save
end
end


def remove(session)
@data.reject! { |t| t['session'] == session }
save
end
end
end
