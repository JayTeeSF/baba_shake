package main

import (
	"fmt"
	"math/rand"
	"time"
)

type color struct {
	percentage float64
	name       string
	code       string
}

type timed_color struct {
	Color      color
	Sleep_time float64
}

type ui_options struct {
	number_of_characters_to_backup int
	color                          color
}

var maximum_number_of_colors_to_present int = 99 * 3
var seconds_before_we_start_discounting_points float64 = 1.38

func red() color {
	return color{name: "red", code: "\033[0;31m", percentage: 33.3}
}

func orange() color {
	return color{name: "orange", code: "\033[1;31m", percentage: 67.2}
}

func yellow() color {
	return color{name: "yellow", code: "\033[1;33m", percentage: 82.3}
}

func green() color {
	return color{name: "green", code: "\033[0;32m", percentage: 100.0}
}

func float_sample(answers []float64) float64 {
	return answers[rand.Intn(len(answers))]
}

func too_fast() float64 {
	//answers := []float64{0.033, 0.038, 0.042, 0.045}
	answers := []float64{0.0610}
	return float_sample(answers)
}

func fast() float64 {
	answers := []float64{0.083, 0.097, 0.1, 0.099}
	return float_sample(answers)
}

func slow() float64 {
	answers := []float64{0.11, 0.23, 0.31, 0.30}
	return float_sample(answers)
}

func per_second_discount_rate_sample() float64 {
	answers := []float64{3.13, 2.47}
	return float_sample(answers)
}

func color_cycle() []func() color {
	func_array := []func() color{red, orange, yellow, green, yellow, orange, red}
	return func_array
}

func color_enumerator(c chan *timed_color) {
	colors := color_cycle()
	cycle_length := len(colors)
	for i := 0; i < cycle_length; i++ {
		rec := &timed_color{Color: colors[i](), Sleep_time: too_fast()}
		c <- rec
	}

	for j := 0; j <= 2; j++ {
		for i := 0; i < cycle_length; i++ {
			rec := &timed_color{Color: colors[i](), Sleep_time: fast()}
			c <- rec
		}
	}

	for true {
		for i := 0; i < cycle_length; i++ {
			rec := &timed_color{Color: colors[i](), Sleep_time: slow()}
			c <- rec
		}
	}
}

func ui_clear() {
	ui_print("\033[2J", ui_options{})
}

func ui_reset() {
	ui_print("\033[0;0H", ui_options{})
}

func backup_the_cursor(number_of_characters int) string {
	return fmt.Sprintf("\033[%dD", number_of_characters)
}

func ui_print(message string, options ui_options) {
	if options.number_of_characters_to_backup > 0 {
		fmt.Printf(backup_the_cursor(options.number_of_characters_to_backup))
	}
	fmt.Printf("%s%s%s", options.color.code, message, options.color.code)
}

func ui_puts(message string, options ui_options) {
	ui_print(fmt.Sprintf("%s\n", message), options)
}

func listen_for_input(c chan bool) {
	<-c
	var input string
	fmt.Scanln(&input)
	c <- false
}

func random_point_discount_based_on(elapsed_time float64) float64 {
	return per_second_discount_rate_sample() * elapsed_time
}

func percentage_of_points_to_keep_based_on_selected(color color) float64 {
	return color.percentage / 100.0
}

func main() {
	var sleep_time float64
	var color color
	c := make(chan *timed_color)
	sc := make(chan bool)
	ui_reset()
	reverse_display := false
	points := 100.0
	keep_looping := true

	number_of_colors_presented := 0
	previous_color_length := 0
	number_of_colors_presented_when_last_reversed := 0

	go color_enumerator(c)
	for i := 0; i <= 2; i++ {
		rec := <-c
		color = rec.Color
		ui_print(color.name, ui_options{color: color})
		number_of_colors_presented += 1
	}
	ui_clear()

	color = red()
	sleep_time = 0
	go listen_for_input(sc)
	timer := time.NewTimer(time.Duration(sleep_time))
	t0 := time.Now()
	for keep_looping {
		number_of_characters_to_backup := 0

		// after displaying a full cycle of colors: L->R
		// display the next cycle walking backward: L<-R
		if (number_of_colors_presented - number_of_colors_presented_when_last_reversed) >= len(color_cycle()) {
			number_of_colors_presented_when_last_reversed = number_of_colors_presented
			reverse_display = !reverse_display // toggle
		}
		if number_of_colors_presented >= maximum_number_of_colors_to_present {
			ui_print("too many times...", ui_options{})
			keep_looping = false
			color = red()
		} else {
			select {
			case keep_looping = <-sc: // key pressed
			case <-timer.C:
				rec := <-c
				color = rec.Color
				if reverse_display || (number_of_colors_presented_when_last_reversed == number_of_colors_presented) {
					number_of_characters_to_backup = len(color.name) + previous_color_length
					previous_color_length = len(color.name)
				} else {
					previous_color_length = 0
				}
				// erase what was written before (leaving cursor where it is):
				ui_clear()
				ui_print(color.name, ui_options{color: color, number_of_characters_to_backup: number_of_characters_to_backup})
				// start listening for user input
				if 0 == sleep_time {
					sc <- true
				}
				sleep_time = rec.Sleep_time
			}
		}
		number_of_colors_presented += 1
		timer = time.NewTimer(time.Duration(float64(time.Second) * sleep_time))
	}
	elapsed_time := time.Since(t0)
	if elapsed_time.Seconds() > seconds_before_we_start_discounting_points {
		points = points - random_point_discount_based_on(elapsed_time.Seconds())
	}
	points = points * percentage_of_points_to_keep_based_on_selected(color)
	ui_puts(fmt.Sprintf("\nAfter %fs you landed on: %s for %f points", elapsed_time.Seconds(), color.name, points), ui_options{color: color})
}
