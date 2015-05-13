module Representable
  module Cached
    def representable_mapper(*)
      @mapper ||= super.tap do |mapper|
        mapper.bindings.each { |binding| binding.extend(Binding) }
      end
    end

    # replace represented for each property in this representer.
    # DISCUSS: not sure if we need to replace self and user_options.
    def update!(represented, user_options)
      representable_mapper.bindings.each do |binding|
        binding.update!(represented, self, user_options)
        # binding.instance_variable_set(:@represented, represented)
        # binding.instance_variable_set(:@exec_context, represented)
      end
    end

    # TODO: also for deserializer.
    # TODO: create Populator in Binding, too (easier to override).
    module Binding
      def serializer
        @__serializer ||= super.tap do |serializer|
          puts "extendin"
          serializer.extend(Serializer)
        end
      end
    end

    module Serializer
      def prepare_for(mod, object)
        if representer = @binding.instance_variable_get(:@__representer)
          representer.update!(object, @binding.user_options) # FIXME: @binding.user_options is wrong, it's the old options in case this class gets cached.
          return representer
        end

        representer = super(mod, object)
        @binding.instance_variable_set(:@__representer, representer)
        representer
      end
    end
  end
end