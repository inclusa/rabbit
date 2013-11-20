name = "slide-logo"

if @slide_logo_image.nil?
  theme_exit(_("must specify %s!!!") % "@slide_logo_image")
end

@slide_logo_position ||= :right
@slide_logo_width ||= nil
@slide_logo_height ||= canvas.height * 0.1

match(SlideElement) do
  delete_pre_draw_proc_by_name(name)

  break if @slide_logo_image_uninstall

  loader = ImageLoader.new(find_file(@slide_logo_image))

  add_pre_draw_proc(name) do |slide, canvas, x, y, w, h, simulation|
    unless simulation
      slide_logo_width = @slide_logo_width
      slide_logo_height = @slide_logo_height
      if slide_logo_width.respond_to?(:call)
        slide_logo_width = slide_logo_width.call(slide, canvas)
      end
      if slide_logo_height.respond_to?(:call)
        slide_logo_height = slide_logo_height.call(slide, canvas)
      end
      loader.resize(slide_logo_width, slide_logo_height)

      case @slide_logo_position
      when :right
        logo_x = canvas.width - loader.width
        logo_y = 0
      when :left
        logo_x = 0
        logo_y = 0
      else
        if @slide_logo_position.respond_to?(:call)
          logo_x, logo_y = @slide_logo_position.call(slide, canvas, loader)
        else
          logo_x, logo_y = @slide_logo_position
        end
      end
      loader.draw(canvas, logo_x, logo_y)
    end
    [x, y, w, h]
  end
end
