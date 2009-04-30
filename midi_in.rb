# This is a mild refactor of this code:
# http://github.com/gilesbowkett/rbcoremidi/blob/ca3fa0954f3064d92b68df94e7e597e34f95009b/midi_in.rb

# Doesn't slam the processor when capturing: rate limited (somewhat inelegantly) to 1KHz.

require 'coremidi'

class Controller < Struct.new(:controller, :data) ; end
class Note < Struct.new(:on_off, :note_number, :velocity) ; end

class MidiIn
  include CoreMIDI

  CAPTURE_INTERVAL= 0.001

  def initialize
    # Names are arbitrary
    client = CoreMIDI.create_client("SB")
    @port = CoreMIDI.create_input_port(client, "PortA")
  end

  def scan
    CoreMIDI.sources.each_with_index do |source, index|
      puts "source #{index}: #{source}"
    end
  end

  def link(source)
    connect_source_to_port(source, @port) # 0 is index into CoreMIDI.sources array
  end

  def capture
    time = Time.now
    while true
      prev_time = time
      time = Time.now
      interval = time - prev_time
      sleep(CAPTURE_INTERVAL - interval) unless interval > CAPTURE_INTERVAL
      if packets = new_data?
        yield parse(packets)
      end
    end
  end

  def parse(packets)
    packets.collect do |packet|
      outputs = []
      while (d = packet.data.slice!(0,3)).length > 0
        case d[0]
        when 144..146
          outputs << Note.new(:on, d[1], d[2])
        when 128..130
          outputs << Note.new(:off, d[1], d[2])
        when 176
          outputs << Controller.new(d[1], d[2])
        end
      end
      outputs
    end.flatten
  end
end