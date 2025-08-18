# core/profiles.rb
require 'json'
require 'fileutils'
module Hackberry
  class Profiles
    def initialize(path)
      @path = path
      @data = load
    end

    def load
      JSON.parse(File.read(@path))
    rescue
      {}
    end

    def save
      FileUtils.mkdir_p(File.dirname(@path))
      File.write(@path, JSON.pretty_generate(@data))
    end

    def get(mod_id, action_id)
      @data.dig(mod_id, action_id) || {}
    end

    def set(mod_id, action_id, inputs)
      @data[mod_id] ||= {}
      @data[mod_id][action_id] = inputs
      save
    end
  end
end
