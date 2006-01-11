module Rabbit
  module Action
    module_function
    @@radio_blank_values = [
      [:white, 1],
      [:black, 2],
      [:show, 3],
    ]
    def act_radio_blank(action, current, group, canvas)
      case @@radio_blank_values.rassoc(current.value)[0]
      when :white
        canvas.toggle_white_out
      when :black
        canvas.toggle_black_out
      when :show
        if canvas.white_outing?
          canvas.toggle_white_out
        elsif canvas.black_outing?
          canvas.toggle_black_out
        end
      else
        p "????"
      end
    end
    
    def act_radio_blank_white_out_config(config, canvas)
      config[:label] = N_("White out")
      config[:value] = @@radio_blank_values.assoc(:white)[1]
      config[:default] = canvas.white_outing?
    end
    def act_radio_blank_black_out_config(config, canvas)
      config[:label] = N_("Black out")
      config[:value] = @@radio_blank_values.assoc(:black)[1]
      config[:default] = canvas.black_outing?
    end
    def act_radio_blank_show_config(config, canvas)
      config[:label] = N_("Show")
      config[:value] = @@radio_blank_values.assoc(:show)[1]
      config[:default] = !canvas.white_outing? && !canvas.black_outing?
    end
  end
end