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

	_device := device.create_device()

	_surface := device.create_surface(_instance, &_window)
	defer device.destroy_surface(_surface, _instance, &_window)

	device.pick_physical_device(&_device, _instance.instance, _surface.surface)

	device.create_logical_device(&_device, _instance, _surface)
	defer device.destroy_logical_device(_device)

	_swap_chain := device.create_swap_chain(_device, _surface, &_window)
	defer device.destroy_swap_chain(_device, _swap_chain)

	for !window.is_window_closed(_window) {
		window.poll_window_events()
	}
}
