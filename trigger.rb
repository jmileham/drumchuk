module DrumChuk
  class Trigger
    SWING_THRESHOLD = -0.25 # in G
    STRIKE_THRESHOLD = -0.0 # in G
    FULL_VELOCITY = 6.1 # in m/s (this is really approximate...)

    VEL_RANGE = 0.7 # in % of full dynamic range (can be >1).  Lower == narrower dynamic range, but FULL_VELOCITY still == 127
    
    REBOUND_SUPPRESSION_TIMEOUT = 0.4 # in sec
    REBOUND_SUPPRESSION_THRESHOLD = 0.6 # in % of previous note velocity

    def initialize(to_g, x_controller, y_controller, z_controller, buttons, note_proc)
      @to_g = to_g
      @x_controller = x_controller
      @y_controller = y_controller
      @z_controller = z_controller
      @buttons = buttons
      @note_proc = note_proc

      @x = 0
      @y = 0
      @z = 0
      @radius = 0
      @swing_start = nil
      @swing_velocity = 0
      @rolls = []
      @pitches = []
    end

    def process(d)
      if d.class == Controller
        # Update our stored X or Y G-readings if this is one of our designated axes
        case d.controller
        when @x_controller
          @x = @to_g.call(d.data)
        when @y_controller
          @y = @to_g.call(d.data)
        when @z_controller
          @z = @to_g.call(d.data)
        end
      end
    end

    def trigger(midi_interface)
      # Keep the previous radius value around to compare for fall-offs in 
      @radius = Math::sqrt(@x**2 + @y**2 + @z**2) * (@z > 0 ? 1 : -1)

      @prev_roll = @roll
      @roll = theta(@x, @z)

      @prev_pitch = @pitch
      @pitch = theta(@y, @z)

      if !@swing_start and @radius < SWING_THRESHOLD
        @swing_start = Time.now
      end

      if @swing_start
        @prev_time = (@curr_time || @swing_start)
        @curr_time = Time.now
        @sample = (-@radius) * (@curr_time - @prev_time) * 9.8
        @swing_velocity += @sample
        @rolls << @roll
        @pitches << @pitch

        if @radius > STRIKE_THRESHOLD
          velocity = to_midi_velocity(@swing_velocity)
          roll = denoised_average(@rolls)
          pitch = @pitch
          if (@suppress_rebound_until.nil? or @suppress_rebound_until <= Time.now or velocity > @last_velocity * REBOUND_SUPPRESSION_THRESHOLD)
            notes = @note_proc.call(velocity, roll, pitch, @buttons)
            notes.each { |note| midi_interface.play(note, velocity) }
            # Suppress rebounds on back-wrist strikes and loud strikes
            if pitch < 30
              @suppress_rebound_until = Time.now + REBOUND_SUPPRESSION_TIMEOUT
            end

            puts({:notes => notes, :velocity => velocity, :roll => roll, :pitch => pitch, }.inspect)
            @last_velocity = velocity
          end
          @swing_start = nil
        end

      end

    end

    def update()
      if @swing_start == nil
        @swing_velocity = 0
        @rolls = []
        @pitches = []
        @curr_time = nil
      end    
    end

    protected

    def denoised_average(ary)
      outliers = (ary.length * 0.2).round
      ary = ary.sort.slice(outliers, ary.length-(outliers * 2).round)
      ary.inject { |sum, n| sum + n } / ary.length
    end

    def theta(x, y)
      if y == 0.0
        x < 0 ? -90 : 90
      else
        (Math::atan(x / y) * (180 / Math::PI)).round
      end
    end

    def to_midi_velocity(s)
      s = s / FULL_VELOCITY
      s = 1.0 if s > 1.0
      s = 0.0 if s < 0.0
      (s * VEL_RANGE * 127).round + (127 - (VEL_RANGE * 127).round)
    end
  end
end