# Version 0.4.  More cowbell.

# This is where you set up your trigger mappings.

# Which note(s) to play is/are determined by a lambda you provide.  Your lambda is given:
# * MIDI velocity (0..127)
# * Roll (in degrees -90..90)
# * Pitch (in degrees -90..90)
# * buttons, which can be used to determine down-state of buttons
# Just return an array of MIDI note numbers.  DrumChuk::NoteNumbers has a few handy General MIDI drum note mappings.

# Add whatever the location of rbcoremidi is here...
$LOAD_PATH << '../rbcoremidi'

require 'midi_interface'
require 'button_set'
require 'note_numbers'
require 'trigger'

include DrumChuk::NoteNumbers

# Does your tone generator have a rimshot sample?  If not, true is good.
SUPPRESS_RIMSHOT = true

# A spoonful of syntax sugar
def returning(value)
  yield(value)
  value
end

midi_interface = DrumChuk::MidiInterface.new

quiet_hat_stomp = {:hit_note => GM_HATS_STOMP, :hit_velocity => 64}

buttons = DrumChuk::ButtonSet.new(midi_interface, {
  :b_button => quiet_hat_stomp,
  :z_button => quiet_hat_stomp
})
midi_interface.register_listener(buttons)

left_hand = lambda do |velocity, roll, pitch, buttons|
  returning [] do |notes|
    case roll
    when -90..-16
      # Pick up wide mis-hits as rimshots
      if pitch > 25 or SUPPRESS_RIMSHOT
        notes << GM_CRASH_1
      else
        notes << RIMSHOT
      end      
    when -15..45
      if pitch > 25 or SUPPRESS_RIMSHOT
        notes << GM_SNARE
      else
        notes << RIMSHOT
      end      
    when 46..100
      notes << GM_HI_TOM
    end
  end
end

right_hand = lambda { |velocity, roll, pitch, buttons|
  returning [] do |notes|
    case roll
    when -100..-36
      if pitch > -55
        notes << (buttons.down?(:b_button) || buttons.down?(:z_button) ? GM_HATS_CLOSED : GM_HATS_OPEN)
      end
      if pitch < 30
        notes << GM_KICK
      end      
    when -35..20
      if pitch > 30
        notes << SNARE_RIGHT
      else
        notes << GM_KICK
      end      
    when 21..100
      notes << GM_LOW_TOM
    end
  end
}

# Wiimote

# Calibration for converting controller data to G
to_g_left = lambda {|v| (v - 59.5) / 4.8 }
midi_interface.register_listener(DrumChuk::Trigger.new(to_g_left, 16, 17, 18, buttons, left_hand))

# Nunchuk
to_g_right = lambda {|v| (v - 59.5) / 5.2}
midi_interface.register_listener(DrumChuk::Trigger.new(to_g_right, 19, 20, 21, buttons, right_hand))


# The main event loop
midi_interface.run_triggers :if => lambda { buttons.down?(:a_button) }    
