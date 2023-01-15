module main

import json
import net.http
import os
import time

import arrays
import term

import progressbar

struct Place {
	place_id int
	lat string
	lon string
	display_name string
}

struct Times {
mut:
	time []int
	temperature_2m_max []f64
	temperature_2m_min []f64

	rain_sum []f64

}

struct Temps {
mut:
	daily Times
}

fn main() {

	zip_code := os.input("What is your zip-code ? ")
	data := http.get_text("https://geocode.maps.co/search?postalcode=$zip_code")
	places := json.decode([]Place, data) or { panic(err) }
	
	mut chosen_place := Place{}

	if places.len > 1 {

		println("There are multiple places with that zip code, please choose:")
		for i in 0..places.len {
			println("ID $i: " + term.colorize(term.cyan, "${places[i].display_name}"))
		}
		println("")
		opt := os.input(term.colorize(term.bright_white, "Option (Default 0): ")).int()
		if opt < 0 || opt > places.len - 1 {
			println("Invalid ID")
			exit(1)
		}
		println(term.colorize(term.green, "Option $opt chosen"))
		chosen_place = places[opt]

	} else if places.len == 0 {
		println("Unknown zip-code")
		exit(1)
	} else {
		chosen_place = places[0]
	}

	// println(term.colorize(term.bright_magenta, "Getting data..."))

	mut p := progressbar.Progressbar{}
	p.new_with_format(term.colorize(term.bright_magenta, "Getting data"), 4, ["|", term.bg_white(" "), "|"])


	url := "https://archive-api.open-meteo.com/v1/archive?latitude=${chosen_place.lat.f64():.2}&longitude=${chosen_place.lon.f64():.2}&start_date=1959-01-01&end_date=${time.now().custom_format("YYYY-MM-DD")}&daily=temperature_2m_max&timezone=auto&temperature_unit=fahrenheit&windspeed_unit=mph&precipitation_unit=inch&timeformat=unixtime"
	min_url := "https://archive-api.open-meteo.com/v1/archive?latitude=${chosen_place.lat.f64():.2}&longitude=${chosen_place.lon.f64():.2}&start_date=1959-01-01&end_date=${time.now().custom_format("YYYY-MM-DD")}&daily=temperature_2m_min&timezone=auto&temperature_unit=fahrenheit&windspeed_unit=mph&precipitation_unit=inch&timeformat=unixtime"

	rain_url := "https://archive-api.open-meteo.com/v1/archive?latitude=${chosen_place.lat.f64():.2}&longitude=${chosen_place.lon.f64():.2}&start_date=1959-01-01&end_date=${time.now().custom_format("YYYY-MM-DD")}&daily=rain_sum&timezone=auto&temperature_unit=fahrenheit&windspeed_unit=mph&precipitation_unit=inch&timeformat=unixtime"

	p.increment()

	r := http.get(url) or { panic(err) }
	mut changed := r.body
	changed = changed.replace(",null", "")
	mut encoded := json.decode(Temps, changed) or { panic(err) }
	encoded.daily.time = encoded.daily.time[..encoded.daily.temperature_2m_max.len+1]
	p.increment()
	
	r_min := http.get(min_url) or { panic(err) }
	mut min_changed := r_min.body
	min_changed = min_changed.replace(",null", "")
	mut min_encoded := json.decode(Temps, min_changed) or { panic(err) }
	min_encoded.daily.time = min_encoded.daily.time[..min_encoded.daily.temperature_2m_min.len+1]
	p.increment()
	 
	r_rain := http.get(rain_url) or { panic(err) }
	mut rain_changed := r_rain.body
	rain_changed = rain_changed.replace(",null", "")
	mut rain_encoded := json.decode(Temps, rain_changed) or { panic(err) }
	rain_encoded.daily.time = rain_encoded.daily.time[..rain_encoded.daily.rain_sum.len+1]
	p.increment()

	p.finish()

	mut selected_day := os.input(term.colorize(term.bright_white, "Day to predict temperature (Format MM-DD or M-D, Ex. 01-13 or 1-13) (Default = tommorow): "))
	if selected_day == "" {
		println(term.colorize(term.green, "Defaulting to tommorow..."))
		selected_day = time.now().add_days(1).custom_format("MM-DD")
	}
	selected_time := time.parse("${time.now().year}-$selected_day 00:00:00") or { panic(err) }

	if selected_time <= time.now() {
		println("Selected day has to be after current day")
		exit(1)
	}

	println(term.colorize(term.bright_magenta, "Calculating using last ${time.now().year - 1959} years of data..."))
	p.new_with_format(term.colorize(term.bright_magenta, "Calculating"), u64(encoded.daily.temperature_2m_max.len), ["|", term.bg_white(" "), "|"])

	days := encoded.daily
	min_days := min_encoded.daily

	rain_days := rain_encoded.daily

	mut temps := []f64{}
	mut max_temps := []f64{}
	mut min_temps := []f64{}

	mut rain := []f64{}

	mut since_last := u64(0)

	for i in 0..days.temperature_2m_max.len {
		t := time.unix(days.time[i])
		since_last++
		if t.month == selected_time.month && t.day == selected_time.day && t.year != selected_time.year {
			temps << (days.temperature_2m_max[i] + min_days.temperature_2m_min[i]) / 2
			min_temps << min_days.temperature_2m_min[i]
			max_temps << days.temperature_2m_max[i]

			rain << rain_days.rain_sum[i]
			p.add(since_last)
			since_last = 0
			time.sleep(1*time.millisecond)


		}
		
		// time.sleep(1 * time.millisecond)
	}
	p.add(since_last)
	
	ans := ["${((arrays.sum(temps) or { panic(err) }) / temps.len):.5}", "${((arrays.sum(max_temps) or { panic(err) }) / max_temps.len):.5}", "${((arrays.sum(min_temps) or { panic(err) }) / min_temps.len):.5}", "${((arrays.sum(rain) or { panic(err) }) / rain.len):.2}"]

	p.finish()

	if term.can_show_color_on_stdout() {
		println("\nPredicted temperature: ${term.bright_green(ans[0])} ${rune(176)}F")
		println("Predicted high: ${term.bright_green(ans[1])} ${rune(176)}F")
		println("Predicted low: ${term.bright_green(ans[2])} ${rune(176)}F")

		println("Predicted rain: ${term.bright_green(ans[3])} inches")


	} else {
		println("\nPredicted temperature: ${ans[0]} ${rune(176)}F")
		println("Predicted high: ${ans[1]} ${rune(176)}F")
		println("Predicted low: ${ans[2]} ${rune(176)}F")

		println("Predicted rain: ${ans[3]} inches")
	}


}
