# encoding: UTF-8

module Spontaneous
  module Render
    class PublishedRenderer < Renderer
      NGINX_DETECT_HEADER = "X-Nginx"
      NGINX_ACCEL_REDIRECT = "X-Accel-Redirect"

      def render_content(content, format=:html, params = {})
        request  = params[:request]
        response = params[:response]
        headers  = request.env
        revision = Content.revision
        render   = nil

        if Spontaneous.development? and Spontaneous.config.rerender_pages
          # in dev mode we just want to render the page dynamically, skipping the cached version
          render = rerender(content, format, params)
        else
          # first test for dynamic template
          template = Spontaneous::Render.output_path(revision, content, format, extension, true)

          if File.exists?(template)
            render = request_renderer.render_file(template, content, format, params)
          else

            # if no dynamic template exists then try for a static file
            # this case will normally be handled by the proxy server (nginx, apache...)
            # in production environments
            template = Spontaneous::Render.output_path(revision, content, format)

            if File.exists?(template)
              render = File.open(template)
            else
              # and if all else fails, just re-render the damn thing
              render = rerender(content, format, params)
            end
          end
        end
        render
      end

      def rerender(content, format = :html, params = {})
        template = S::Render.with_publishing_renderer do
          publishing_renderer.render_file(content.template(format), content, format)
        end
        request_renderer.render_string(template, content, format, params)
      end

      def render_string(template_string, content, format=:html, params = {})
        request_renderer.render_string(template_string, content, format, params)
      end
    end # PublishedRenderer
  end # Render
end # Spontaneous
