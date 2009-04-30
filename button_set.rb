module DrumChuk
  class ButtonSet

    BUTTON_MAP = {
      :a_button => 60,
      :b_button => 62,
      :c_button => 65,
      :z_button => 69,
    }

    def initialize(midi_interface, trigger_map)
      @midi_interface = midi_interface
      @trigger_map = trigger_map
      @button_states = BUTTON_MAP.keys.inject({}) { |button_states, b| button_states[b] = :off; button_states }
    end

    def process(d)
      if d.class == Note
        # update button state if the note that came in happens to be a designated button
        BUTTON_MAP.each do |button_name, button_note|
          if d.note_number == button_note
            if d.on_off == :on
              @button_states[button_name] = :hit if @button_states[button_name] == :off
            else
              @button_states[button_name] = :release if @button_states[button_name] == :on
            end
          end
        end  
      end
    end

    def trigger(midi_interface)
      @trigger_map.each do |button_name, note_info|
        if @button_states[button_name] == :hit
          midi_interface.play(note_info[:hit_note], note_info[:hit_velocity]) if note_info[:hit_note]
        end
        if @button_states[button_name] == :release
          midi_interface.play(note_info[:release_note], note_info[:release_velocity]) if note_info[:release_note]
        end
      end
    end

    def update()
      @button_states.each do |button_name, state|
        @button_states[button_name] = case state when :hit then :on; when :release then :off; else state end
      end
    end

    def down?(button_name)
      [:on, :hit].include?(@button_states[button_name])
    end
  end
end