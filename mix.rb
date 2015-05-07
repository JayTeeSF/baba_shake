#!/usr/bin/env ruby

class StdUi
  ANSI_CLEAR    = "\033[2J"
  ANSI_BACKUP_FMT = "\033[%sD"
  ANSI_RESET_CURSOR = "\033[0;0H"

  ANSI_LOOKUP = {
    red: "\033[0;31m",
    yellow: "\033[1;33m",
    green: "\033[0;32m",
    orange: "\033[1;31m"
  }.freeze

  def clear
    print ANSI_CLEAR
  end

  def reset
    print(ANSI_RESET_CURSOR)
  end

  def print(message="", options={})
    if !! options[:number_of_characters_to_backup]
      STDOUT.print(backup_the_cursor(options[:number_of_characters_to_backup]))
    end
    pre_color = post_color = ANSI_LOOKUP[options[:color]]
    STDOUT.print("#{pre_color}#{message}#{post_color}")
  end

  def puts(message="", options={})
    print("#{message}\n", options)
  end

  def get
    gets.chomp
  end

  def gets
    STDIN.gets
  end


  private

  def backup_the_cursor(number_of_characters)
    ANSI_BACKUP_FMT % number_of_characters
  end
end

class Mixer
  require 'timeout'

  INITIAL_POINTS = 100
  # how many of those points to keep (based on what user lands on):
  FILL_OPTION_PERCENTAGES =  {red: 33.3, orange: 67.2, yellow: 82.3, green: 100.0 }

  FILL_OPTIONS = [:red, :orange, :yellow, :green ]
  # go through colors forward and backward, but don't double-up on green:
  COLOR_CYCLE = FILL_OPTIONS + FILL_OPTIONS.reverse[1..-1]

  RED = FILL_OPTIONS.first
  DEFAULT_UI = StdUi.new

  # magic-number(s): trial and error to pick the speed at which these options fly-by
  TOO_FAST_TIMES = [0.033, 0.038, 0.042, 0.045]
  FAST_TIMES = [0.083, 0.097, 0.1, 0.099]
   SLOW_TIMES = [0.11, 0.23, 0.31, 0.30]

  # magic-number(s): when to quit the infinite loop: 99 happened to land on red; 3 because 1-time was too quick
  MAXIMUM_NUMBER_OF_COLORS_TO_PRESENT = 99 * 3

  # magic-number(s)
  SECONDS_BEFORE_WE_START_DISCOUNTING_POINTS = 1.38 # seems long enough
  PER_SECOND_POINT_DISCOUNT_RATES = [3.13, 2.47] #?

  def self.mix(options={})
    new(options).mix
  end

  def initialize(options={})
    @ui = options[:ui] || DEFAULT_UI
  end

  def enumerator
    color_enumerator = COLOR_CYCLE.cycle
    Enumerator.new do |yielder|
      COLOR_CYCLE.size.times do
        yielder.yield([color_enumerator.next, TOO_FAST_TIMES.sample])
      end

      3.times do
        COLOR_CYCLE.size.times do
          yielder.yield([color_enumerator.next, FAST_TIMES.sample])
        end
      end

      # allow this enumerator to continue forever:
      loop do
        yielder.yield([color_enumerator.next, SLOW_TIMES.sample])
      end
    end
  end

  def mix
    e = enumerator
    @ui.reset
    reverse_display = false
    points = INITIAL_POINTS
    stopped = false

    number_of_colors_presented = 0
    previous_color_length = 0
    number_of_colors_presented_when_last_reversed = 0

    # start in middle of screen on green
    3.times {
      color, remaining_sleep = e.next
      @ui.print color
      number_of_colors_presented += 1
    }

    color = RED
    start_time = Time.now.to_f
    while !stopped do
      # erase what was written before (leaving cursor where it is):
      @ui.clear

      # after displaying a full cycle of colors: L->R
      # display the next cycle walking backward: L<-R
      if (number_of_colors_presented - number_of_colors_presented_when_last_reversed) >= COLOR_CYCLE.length
        number_of_colors_presented_when_last_reversed = number_of_colors_presented
        reverse_display = !reverse_display # toggle
      end

      if number_of_colors_presented >= MAXIMUM_NUMBER_OF_COLORS_TO_PRESENT
        color = RED
        break
      end

      begin
        color, remaining_sleep = e.next
      rescue StopIteration # not presently using this, given the infinite loop in the enumerator
        break
      end
      options = { color: color }
      # currently reversed or newly-toggled:
      if reverse_display || (number_of_colors_presented_when_last_reversed == number_of_colors_presented)
        options.merge!(number_of_characters_to_backup: color.to_s.length + previous_color_length )
        previous_color_length = color.to_s.length
      else
        previous_color_length = 0
      end
      @ui.print color, options
      stopped = false
      begin
        Timeout::timeout(remaining_sleep) do
          stopped = @ui.get
        end
      rescue Timeout::Error
        stopped = false
      end
      number_of_colors_presented += 1
    end

    end_time = Time.now.to_f
    elapsed_time = end_time - start_time
    points = points - random_point_discount_based_on(elapsed_time) if elapsed_time > SECONDS_BEFORE_WE_START_DISCOUNTING_POINTS
    points = points * percentage_of_points_to_keep_based_on_selected(color)
    @ui.puts "\nAfter #{elapsed_time}s you landed on: #{color} for #{points} points", color: color
    return color
  end

  private

  def random_point_discount_based_on(elapsed_time)
    PER_SECOND_POINT_DISCOUNT_RATES.sample * elapsed_time
  end

  # discount points based on the selected color's weight
  def percentage_of_points_to_keep_based_on_selected(color)
    Float(FILL_OPTION_PERCENTAGES[color]) / 100
  end
end

if __FILE__ == $PROGRAM_NAME
  Mixer.mix
end
