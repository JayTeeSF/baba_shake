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
end

class Mixer
  require 'timeout'

  INITIAL_POINTS = 100
  DEFAULT_UI = StdUi.new
  FILL_OPTIONS = [:red, :orange, :yellow, :green, :yellow, :orange, :red]
  FILL_OPTION_PERCENTAGES =  {red: 33.3, orange: 67.2, yellow: 82.3, green: 100 }
  TOO_FAST_TIMES = [0.036, 0.04, 0.031]
  FAST_TIMES = [0.043, 0.047, 0.050]
  SLOW_TIMES = [0.051, 0.052, 0.053]

  def self.mix(options={})
    new(options).mix
  end

  def initialize(options={})
    @ui = options[:ui] || DEFAULT_UI
    generate_fill_intervals
  end

  def enumerator
    color_enumerator = FILL_OPTIONS.cycle
    final_sleep_time_enumerator = SLOW_TIMES.cycle
    Enumerator.new do |yielder|
      @fill_intervals.each do |sleep_time|
        yielder.yield([color_enumerator.next, sleep_time])
      end

      # allow this enumerator to continue forever:
      loop do
        yielder.yield([color_enumerator.next, final_sleep_time_enumerator.next])
      end
    end
  end

  def generate_fill_intervals
    # TODO:
    # slow down a bit every 3sec, do that for 15 seconds, then default pour. score drops by 25% starting in the (1 (super fast),2 (reasonably fast)) 3rd interval (same ...leaving 75),
    # and continuing in the 4th (again leaving 50), 5th (slower leaving 25%) -- no 0 score.
    @fill_intervals = []
    (FILL_OPTIONS.size * 2).times { @fill_intervals << TOO_FAST_TIMES.sample }
    (FILL_OPTIONS.size * 2).times { @fill_intervals << FAST_TIMES.sample } # still 100%

    (FILL_OPTIONS.size * 2).times { @fill_intervals << FAST_TIMES.sample } # now 75%
    (FILL_OPTIONS.size * 2).times { @fill_intervals << FAST_TIMES.sample } # now 50%

    (FILL_OPTIONS.size * 2).times { @fill_intervals << SLOW_TIMES.sample } # now 25% ...and done
    @fill_intervals.flatten
  end

  def mix
    start_time = Time.now.to_f
    points = INITIAL_POINTS
    color = FILL_OPTIONS.last
    stopped = false
    e = enumerator
    loop_idx = 0
    reset_interval = FILL_OPTIONS.size
    last_reset = -reset_interval

    while !stopped do
      loop_idx += 1
      @ui.clear
      if (loop_idx - last_reset) >= reset_interval
        last_reset = loop_idx
        @ui.reset
      end

      if loop_idx >= 99 * 3
        color = FILL_OPTIONS.last
        break
      end

      begin
        color, remaining_sleep = e.next
      rescue StopIteration # not presently using this, given the infinite loop
        break
      end
      @ui.print color, color: color
      stopped = false
      begin
        Timeout::timeout(remaining_sleep) do
          stopped = @ui.get
        end
      rescue Timeout::Error
        stopped = false
      end
    end

    end_time = Time.now.to_f
    elapsed_time = end_time - start_time
    points -= ([3.13, 2.47].sample * elapsed_time) if elapsed_time > 1.1 # magic-number(s): give 'em a second before we discount their score
    points *= (Float(FILL_OPTION_PERCENTAGES[color]) / 100) # number_to_percentage
    @ui.puts "\nAfter #{elapsed_time}s you landed on: #{color} for #{points} points", color: color
    return color
  end
end

if __FILE__ == $PROGRAM_NAME
  Mixer.mix
end
