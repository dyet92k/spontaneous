# encoding: UTF-8

require 'mini_magick'
require 'delegate'

module Spontaneous
  module FieldTypes

    module ImageFieldUtilities
      attr_accessor :template_params

      def render(format=:html, *args)
        case format
        when :html
          to_html(*args)
        else
          value
        end
      end

      def to_html(attr={})
        default_attr = {
          :src => src,
          :width => width,
          :height => height,
          :alt => ""
        }
        default_attr.delete(:width) if width.nil?
        default_attr.delete(:height) if height.nil?
        if template_params && template_params.length > 0 && template_params[0].is_a?(Hash)
          attr = template_params[0].merge(attr)
        end
        if attr.key?(:width) || attr.key?(:height)
          default_attr.delete(:width)
          default_attr.delete(:height)
          if (attr.key?(:width) && !attr[:width]) || (attr.key?(:height) && !attr[:height])
            attr.delete(:width)
            attr.delete(:height)
          end
        end
        attr = default_attr.merge(attr)
        params = []
        attr.each do |name, value|
          params << %(#{name}="#{value.to_s.escape_html}")
        end
        %(<img #{params.join(' ')} />)
      end

      def to_s
        src
      end

      def /(value)
        return value if self.blank?
        self
      end
    end

    class ImageField < Field
      include Spontaneous::Plugins::Field::EditorClass
      include ImageFieldUtilities

      def self.accepts
        %w{image/(png|jpeg|gif)}
      end

      def self.size(name, &process)
        self.sizes[name.to_sym] = process

        unless method_defined?(name)
          class_eval <<-IMAGE
            def #{name}
              sizes[:#{name}]
            end
          IMAGE
        end
      end

      def self.sizes
        size_definitions
      end

      def self.validate_sizes(sizes)
        sizes
      end

      def self.size_definitions
        @size_definitions ||= superclass.respond_to?(:size_definitions) ? superclass.size_definitions.dup : {}
      end

      def image?
        true
      end

      def sizes
        @sizes ||= Hash.new { |hash, key| hash[key] = ImageAttributes.new(processed_values[key]) }
      end

      # value used to show conflicts between the current value and the value they're attempting to enter
      def conflicted_value
        value
      end

      # original is special and should always be defined
      def original
        @original ||= sizes[:original]
      end

      def width
        original.width
      end

      def height
        original.height
      end

      def filesize
        original.filesize
      end

      def src
        original.src
      end

      def filepath
        unprocessed_value
      end

      # formats are irrelevant to image/file fields
      def outputs
        [:original].concat(self.class.size_definitions.map { |name, process| name })
      end

      def value(format=:html, *args)
        sizes[:original].src
      end

      def generate(output, media_file)
        return { :src => media_file } if media_file.is_a?(String)#File.exist?(image_path)
        image = ImageProcessor.new(media_file)
        result = \
          case output
          when :original
            image
          else
            process = self.class.size_definitions[output]
            image.apply(process, output)
          end
        result.serialize
      end

      def preprocess(image_path)
        filename = mimetype = nil
        case image_path
        when Hash
          mimetype = image_path[:type]
          filename = image_path[:filename]
          image_path = image_path[:tempfile].path
        when String
          # return image_path unless File.exist?(image_path)
          filename = ::File.basename(image_path)
        end
        return image_path unless File.exist?(image_path)
        # media_path = owner.make_media_file(image_path, filename)
        media_file = Spontaneous::Media::File.new(owner, filename, mimetype)
        media_file.copy(image_path)
        set_unprocessed_value(File.expand_path(media_file.filepath))
        # media_path
        # image_path
        media_file
      end

      def export(user = nil)
        super(user).merge({
          :processed_value => processed_values
        })
      end
    end


    class ImageAttributes
      include ImageFieldUtilities

      attr_reader  :src, :width, :height, :filesize, :filepath

      def initialize(params={})
        params ||= {}
        @src, @width, @height, @filesize, @filepath = params[:src], params[:width], params[:height], params[:filesize], params[:path]
      end

      def serialize
        {
          :src => src,
          :width => width,
          :height => height,
          :filesize => filesize,
          :path => filepath
        }
      end

      def inspect
        %(<#{self.class.name}: src=#{src.inspect} width="#{width}" height="#{height}">)
      end

      def blank?
        src.blank?
      end

      alias_method :empty?, :blank?
    end

    class ImageProcessor
      include ImageFieldUtilities

      class ImageDelegator < SimpleDelegator

        def initialize(image)
          super(image)
        end

        alias_method :image, :__getobj__

        def format(*args, &block)
          image.format(*args, &block)
        end

        def fit(width, height)
          image.combine_options do |c|
            c.add(:geometry, "#{width}x#{height}>")
          end
        end

        def crop(width, height)
          image.combine_options do |c|
            dimensions = "#{width}x#{height}"
            c.add(:geometry, "#{dimensions}^")
            c.add(:gravity, "center")
            c.add(:crop, "#{dimensions}+0+0!")
          end
        end

        def width(width)
          image.combine_options do |c|
            c.add(:geometry, "#{width}x>")
          end
        end

        def height(height)
          image.combine_options do |c|
            c.add(:geometry, "x#{height}>")
          end
        end

        def greyscale
          image.combine_options do |c|
            c.add(:type, "Grayscale")
          end
        end

        def border_radius(radius, bg_color = nil)
          @image.format('png') if bg_color.nil? or bg_color == 'transparent'
          puts @image.path
          c = MiniMagick::CommandBuilder.new('convert')
          c << @image.path
          c.add(:format, "roundrectangle 0,0 %[fx:w-1],%[fx:h-1], 10,10")
          c.add(:write, "info:tmp.mvg")
          c << @image.path

          puts c.command
          # @image.run(c)
          sub = Subexec.run(c.command, :timeout => MiniMagick.timeout)

          c = MiniMagick::CommandBuilder.new('convert')

          c << @image.path
          # c.add(:write, "info:tmp.mvg")
          c.add(:matte)
          c.add(:bordercolor, "none")
          c.add(:border, "0")
          c.push('\\(')
          c.push("+clone")
          c.add(:alpha, 'transparent')
          c.add(:background, 'white')
          c.add(:fill, 'white')
          c.add(:stroke, 'none')
          c.add(:strokewidth, '0')
          c.add(:draw, "@tmp.mvg")
          c.push('\\)')
          c.add(:compose, 'DstIn')
          c.add(:composite)
          c << @image.path
          puts c.command
          @image.run(c)

        end


        def __run__(process)
          instance_eval(&process)
        end

        def method_missing(method, *args, &block)
          if image.respond_to?(method)
            image.__send__(method, *args, &block)
          else
            image.method_missing(method, *args, &block)
          end
        end
      end

      MAX_DIM = 2 ** ([42].pack('i').size * 8) - 1 unless defined?(MAX_DIM)

      attr_reader :path

      def initialize(media_file)
        @media_file = media_file
        @path = media_file.source
      end

      def src
        @media_file.url
      end

      def filesize
        File.size(path)
      end

      def width
        dimensions[0]
      end

      def height
        dimensions[1]
      end

      def dimensions
        @dimensions ||= Spontaneous::ImageSize.read(path)
      end

      def apply(process, name)
        image = ::MiniMagick::Image.open(path)
        processor = ImageProcessor::ImageDelegator.new(image)
        processor.__run__(process)
        file = @media_file.rename(filename_for_size(name, image))
        file.copy(image.path)

        ImageProcessor.new(file)
      end

      def filename_for_size(name, image)
        original_filename = @media_file.filename
        parts = original_filename.split('.')

        # use the image format for the extension because tempfiles generated by
        # mini_magick don't have extensions
        # I hate the "jpeg" extension though
        ext = image[:format].downcase.gsub(/^jpeg$/, "jpg")
        base = parts[0..-2].join('.')
        filename = [base, name, ext].join('.')
        filename
      end

      def serialize
        {
          :src => src,
          :width => width,
          :height => height,
          :filesize => filesize,
          :path => path
        }
      end

      def inspect
        %(#<ImageProcessor:#{self.object_id} @media_file=#{@media_file.inspect}>)
      end
    end

    ImageField.register(:image, :photo)

  end
end
