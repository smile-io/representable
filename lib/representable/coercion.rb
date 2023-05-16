require "dry-types"

module Representable
  module Coercion
    module Types
      if Gem::Version.new(Dry::Types::VERSION) <= Gem::Version.new('0.14.1')
        include Dry::Types.module
      else
        include Dry::Types()
      end
    end
    class Coercer
      def initialize(type)
        @type = type
      end

      def call(input, _options)
        @type.call(input)
      end
    end


    def self.included(base)
      base.class_eval do
        extend ClassMethods
        register_feature Coercion
      end
    end


    module ClassMethods
      def property(name, options={}, &block)
        super.tap do |definition|
          return definition unless type = options[:type]

          definition.merge!(render_filter: coercer = Coercer.new(type))
          definition.merge!(parse_filter: coercer)
        end
      end
    end
  end
end
