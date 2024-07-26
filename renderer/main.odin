package main

import "core:fmt"
import "device"
import "instance"
import "pipeline"
import "swapchain"
import vk "vendor:vulkan"
import "window"

WIDTH :: 1600
HEIGHT :: 900
TITLE :: "Vertex"

Renderer :: struct {
	_window:     window.Window,
	_instance:   instance.Instance,
	_device:     device.Device,
	_surface:    device.Surface,
	_swap_chain: swapchain.SwapChain,
	_pipeline:   pipeline.GraphicsPipeline,
}

main :: proc() {
	renderer := Renderer{}

	init_renderer(&renderer)

	for !window.is_window_closed(renderer._window) {
		window.poll_window_events()
	}

	shutdown_renderer(&renderer)
}

init_renderer :: proc(renderer: ^Renderer) {
	renderer._window = window.init_window(WIDTH, HEIGHT, TITLE)
	renderer._instance = instance.create_instance(true)
	renderer._device = device.create_device()
	renderer._surface = device.create_surface(
		renderer._instance,
		&renderer._window,
	)
	device.pick_physical_device(
		&renderer._device,
		renderer._instance.instance,
		renderer._surface.surface,
	)
	device.create_logical_device(
		&renderer._device,
		renderer._instance,
		renderer._surface,
	)
	renderer._swap_chain = swapchain.create_swap_chain(
		renderer._device.logical_device,
		renderer._device.physical_device,
		renderer._surface.surface,
		&renderer._window,
	)

	renderer._pipeline = pipeline.create_graphics_pipeline(
		renderer._device.logical_device,
	)

	vk.GetPhysicalDeviceProperties(
		renderer._device.physical_device,
		&renderer._device.properties,
	)
	device.display_device_properties(renderer._device.properties)

	fmt.println("Renderer initialized")
}


shutdown_renderer :: proc(renderer: ^Renderer) {
	// pipeline.destroy_pipeline(renderer._device.logical_device, renderer._pipeline)
	swapchain.destroy_swap_chain(
		renderer._device.logical_device,
		renderer._swap_chain,
	)
	device.destroy_logical_device(renderer._device)
	device.destroy_surface(
		renderer._surface,
		renderer._instance,
		&renderer._window,
	)
	instance.destroy_instance(renderer._instance)
	window.destroy_window(renderer._window)

	fmt.println("Renderer shutdown")
}
