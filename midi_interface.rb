require 'rubygems'
require 'midiator'
require 'midi_in'

module DrumChuk
  class MidiInterface
    MIDI_CHANNEL = 9

    def initialize
      # Grabs the first in available.
      @midi_in = MidiIn.new
      @midi_in.scan
      @midi_in.link(0)

      # Grabs the first out available.
      @midi_out = MIDIator::Interface.new
      @midi_out.autodetect_driver

      @listeners = []
    end

    def register_listener(l)
      @listeners << l
    end

    def run_triggers (params={})
      @midi_in.capture do |data|
        data.each do |d|
          @listeners.each { |l| l.process(d) }
        end
        if params[:if] and params[:if].respond_to?(:call)
          @listeners.each { |l| l.trigger(self) } if params[:if].call
        end
        @listeners.each { |l| l.update }
      end
    end

    def play(note,velocity)
      @midi_out.play(note, 0, MIDI_CHANNEL, velocity)
    end
  end
end