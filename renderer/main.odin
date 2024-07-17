package main

import "device"
import "instance"
import "window"

WIDTH :: 1600
HEIGHT :: 900
TITLE :: "Vertex"

main :: proc() {
	_window := window.init_window(WIDTH, HEIGHT, TITLE)
	defer window.destroy_window(_window)

	_instance := instance.create_instance(true)
	defer instance.destroy_instance(_instance)

	_device := device.pick_physical_device(_instance.instance)
	device.create_logical_device(_instance, &_device)
	defer device.destroy_logical_device(_device)

	for !window.is_window_closed(_window) {
		window.poll_window_events()
	}
}
