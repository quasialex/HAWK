# core/registry.rb
module Hackberry
  class Registry
    @mods = []
    class << self
      attr_reader :mods
      def register(mod_klass)
        @mods << mod_klass
      end
      def by_category
        @mods.group_by(&:category)
      end
      def find(id)
        @mods.find { |m| m.id == id }
      end
    end
  end
end
