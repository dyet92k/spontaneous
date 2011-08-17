# encoding: UTF-8


module Spontaneous
  module FieldTypes
    class Field

      def self.register(*labels)
        labels = self.labels if labels.empty?
        FieldTypes.register(self, *labels)
        self
      end

      def self.labels
        [self.name.demodulize.gsub(/Field$/, '').underscore]
      end

      # def self.prototype=(prototype)
      #   @prototype = prototype
      # end

      # def self.prototype
      #   @prototype
      # end

      def self.accepts
        %w(text/.+)
      end

      def self.accepts?(mime_type)
        accepts.find do |pattern|
          Regexp.new(pattern).match(mime_type)
        end
      end

      attr_accessor :owner, :name, :unprocessed_value, :template_params, :version
      attr_reader   :processed_values


      def initialize(attributes={}, from_db=false)
        @processed_values = {}
        load(attributes, from_db)
      end


      def formats
        if owner
          owner.formats
        else
          [:html]
        end
      end

      def unprocessed_value=(v)
        set_unprocessed_value(v)
        unless @preprocessed
          @modified = (@initial_value != v)
          increment_version if @modified
          self.processed_values = process_formats(@unprocessed_value)
          owner.field_modified!(self) if owner
        end
      end

      def increment_version
        self.version += 1
      end

      def version
        @version ||= 0
      end

      # value used to show conflicts between the current value and the value they're attempting to enter
      def conflicted_value
        unprocessed_value
      end

      # should be overwritten in subclasses that actually do something
      # with the field value
      def process_formats(value)
        values = {}
        value = preprocess(value)
        formats.each do |format|
          process_method = "process_#{format}"
          unless respond_to?(process_method)
            process_method = :process
          end
          values[format] = send(process_method, value)
        end
        values
      end

      def preprocess(value)
        value
      end

      HTML_ESCAPE_TABLE = {
        '&' => '&amp;'
      }

      def escape_html(value)
        value.to_s.gsub(%r{[#{HTML_ESCAPE_TABLE.keys.join}]}) { |s| HTML_ESCAPE_TABLE[s] }
      end

      def process(value)
        value
      end

      # attr_accessor :values

      # override this to return custom values derived from (un)processed_value
      # alias_method :value, :processed_value
      def value(format=:html)
        processed_values[format] || unprocessed_value
      end
      alias_method :processed_value, :value

      def image?
        false
      end

      def to_s(format = :html)
        value(format).to_s
      end

      def render(format=:html, *args)
        value(format)
      end

      def to_html(*args)
        render(:html, *args)
      end

      def to_pdf(*args)
        render(:pdf, *args)
      end

      def value=(value)
        self.unprocessed_value = value
      end

      def mark_unmodified
        @modified = nil
      end

      def modified?
        @modified
      end

      attr_accessor :prototype
      # def prototype
      #   self.class.prototype
      # end

      def schema_id
        self.prototype.schema_id
      end


      def schema_name
        self.prototype.schema_name
      end

      def schema_owner
        self.prototype.owner
      end

      def owner_sid
        schema_owner.schema_id
      end

      def serialize_db
        S::FieldTypes.serialize_field(self)
      end


      def serialized_attributes
        self.attributes.keys.inject({}) do |hash, attribute|
          hash[attribute] = attributes[attribute]
          hash
        end
      end

      def attributes
        @attributes ||= {}
      end

      def attributes=(attr)
        @attributes = attr
      end

      def attribute_get(attribute, *args)
        attributes[attribute.to_sym]
      end

      def attribute_set(attribute, value)
        attributes[attribute.to_sym] = value
      end

      def has_attribute?(attribute_name)
        attributes.key?(attribute_name.to_sym)
      end

      def update(attributes={})
        attributes.each do |property, value|
          setter = "#{property}=".to_sym
          if respond_to?(setter)
            self.send(setter, value)
          end
        end
      end

      # def start_inline_edit_marker
      #   "spontaneous:previewedit:start:field id:#{owner.id} name:#{self.name}"
      # end
      # def end_inline_edit_marker
      #   "spontaneous:previewedit:end:field id:#{owner.id} name:#{self.name}"
      # end

      def export
        {
        :name => name.to_s,
        :id => schema_id.to_s,
        :unprocessed_value => unprocessed_value,
        :processed_value => value(:html),
        :version => version,
        :attributes => attributes
        }
      end

      def inspect
        %(#<#{self.class.name}:#{self.object_id} #{self.serialize_db.inspect}>)
      end

      def blank?
        value.blank?
      end

      def empty?
        value.empty?
      end

      protected

      def load(attributes={}, from_db=false)
        with_preprocessed_values(from_db) do
          attributes.each do |property, value|
            setter = "#{property}=".to_sym
            if respond_to?(setter)
              self.send(setter, value)
            end
          end
        end
      end

      def processed_values=(values)
        @processed_values = values
      end

      def with_preprocessed_values(state=true)
        @preprocessed = state
        yield
      ensure
        @preprocessed = nil
      end

      def method_missing(method_name, *args)
        if self.has_attribute?(method_name)
          attribute_get(method_name, *args)
        else
          super
        end
      end

      def set_unprocessed_value(new_value)
        # initial_value should only be set once so that it can act as a test for field modification
        @initial_value ||= new_value
        @unprocessed_value = new_value
      end

    end
  end
end
