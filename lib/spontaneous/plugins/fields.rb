# encoding: UTF-8

module Spontaneous::Plugins
  module Fields
    module ClassMethods
      def field(name, type=nil, options={}, &block)
        if type.is_a?(Hash)
          options = type
          type = nil
        end

        prototype = FieldPrototype.new(self, name, type, options, &block)
        field_prototypes[name] = prototype
        unless method_defined?(name)
          define_method(name) do |*args|
            fields[name].tap { |f| f.template_params = args }
          end
        else
          # raise "Must give warning when field name clashes with method name #{name}"
        end

        setter = "#{name}=".to_sym
        unless method_defined?(setter)
          define_method(setter) { |value| fields[name].value = value  }
        else
          # raise "Must give warning when field name clashes with method name"
        end
        prototype
      end

      def field_prototypes
        @field_prototypes ||= Spontaneous::PrototypeSet.new(supertype, :field_prototypes)
      end

      def field_names
        field_prototypes.order
      end

      def fields
        field_prototypes
      end

      def field_order(*new_order)
        field_prototypes.order = new_order if new_order and !new_order.empty?
      end

      def field?(field_name)
        field_prototypes.key?(field_name)
      end

      def field_for_mime_type(mime_type)
        fields.find do |prototype|
          prototype.field_class.accepts?(mime_type)
        end
      end

      def readable_fields
        field_prototypes.keys.select { |name| field_readable?(name) }
      end
    end

    module InstanceMethods
      def after_save
        super
        fields.saved
      end

      def reload
        @field_set = nil
        super
      end

      def field_prototypes
        self.class.field_prototypes
      end

      def fields
        @field_set ||= FieldSet.new(self, field_store)
      end

      def field?(field_name)
        self.class.field?(field_name)
      end

      # TODO: unify the update mechanism for these two stores
      def field_modified!(modified_field)
        self.field_store = @field_set.serialize
      end

      def type_for_mime_type(mime_type)
        self.class.allowed_types.find do |t|
          t.field_for_mime_type(mime_type)
        end
      end

      def field_for_mime_type(mime_type)
        prototype = self.class.field_for_mime_type(mime_type)
        self.fields[prototype.name]
      end
    end
  end
end

