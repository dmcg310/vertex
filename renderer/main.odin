package main

import "instance"
import "window"

WIDTH :: 1600
HEIGHT :: 900
TITLE :: "Vertex"

main :: proc() {
	_window := window.init_window(WIDTH, HEIGHT, TITLE)
	defer window.destroy_window(_window)

	_instance := instance.create_instance(false)
	defer instance.destroy_instance(_instance)

	/* !IMPORTANT
	*  vk.load_proc_addresses(device)
	*/

	for !window.is_window_closed(_window) {
		window.poll_window_events()
	}
}
