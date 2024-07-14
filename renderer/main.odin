package main

import "window"

WIDTH :: 1600
HEIGHT :: 900
TITLE :: "Vertex"

main :: proc() {
	_window := window.init_window(WIDTH, HEIGHT, TITLE)
	defer window.destroy_window(_window)

	for !window.is_window_closed(_window) {
		window.poll_window_events()
	}
}
