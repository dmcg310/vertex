package main

import "command"
import "core:fmt"
import "device"
import "framebuffer"
import "instance"
import "pipeline"
import "swapchain"
import "synchronization"
import vk "vendor:vulkan"
import "window"

WIDTH :: 1600
HEIGHT :: 900
TITLE :: "Vertex"

Renderer :: struct {
	_window:              window.Window,
	_instance:            instance.Instance,
	_device:              device.Device,
	_surface:             device.Surface,
	_swap_chain:          swapchain.SwapChain,
	_pipeline:            pipeline.GraphicsPipeline,
	_framebuffer_manager: framebuffer.FramebufferManager,
	_command_pool:        command.CommandPool,
	_command_buffer:      command.CommandBuffer,
	_sync_object:         synchronization.SyncObject,
}

main :: proc() {
	renderer := Renderer{}

	init_renderer(&renderer)

	for !window.is_window_closed(renderer._window) {
		window.poll_window_events()

		render(&renderer)
	}

	vk.DeviceWaitIdle(renderer._device.logical_device)

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
		renderer._swap_chain,
		renderer._device.logical_device,
	)
	renderer._framebuffer_manager = framebuffer.create_framebuffer_manager(
		renderer._swap_chain,
		renderer._pipeline._render_pass,
	)
	for &image_view in renderer._framebuffer_manager.swap_chain.image_views {
		framebuffer.push_framebuffer(
			&renderer._framebuffer_manager,
			&image_view,
		)
	}
	renderer._command_pool = command.create_command_pool(
		renderer._device.logical_device,
		renderer._swap_chain,
	)
	renderer._command_buffer = command.create_command_buffer(
		renderer._device.logical_device,
		renderer._command_pool,
	)
	renderer._sync_object = synchronization.create_sync_object(
		renderer._device.logical_device,
	)

	fmt.println("Renderer initialized")

	vk.GetPhysicalDeviceProperties(
		renderer._device.physical_device,
		&renderer._device.properties,
	)
	device.display_device_properties(renderer._device.properties)
}

render :: proc(renderer: ^Renderer) {
	vk.WaitForFences(
		renderer._device.logical_device,
		1,
		&renderer._sync_object.in_flight_fence,
		true,
		~u64(0),
	)

	image_index: u32
	result := vk.AcquireNextImageKHR(
		renderer._device.logical_device,
		renderer._swap_chain.swap_chain,
		~u64(0),
		renderer._sync_object.image_available_semaphore,
		0,
		&image_index,
	)

	if result != .SUCCESS && result != .SUBOPTIMAL_KHR {
		panic("failed to acquire swap chain image")
	}

	vk.ResetFences(
		renderer._device.logical_device,
		1,
		&renderer._sync_object.in_flight_fence,
	)

	vk.ResetCommandBuffer(renderer._command_buffer.buffer, {})

	command.record_command_buffer(
		renderer._command_buffer,
		renderer._framebuffer_manager,
		renderer._swap_chain,
		renderer._pipeline,
		image_index,
	)

	submit_info := vk.SubmitInfo {
		sType                = .SUBMIT_INFO,
		waitSemaphoreCount   = 1,
		pWaitSemaphores      = &renderer._sync_object.image_available_semaphore,
		pWaitDstStageMask    = &vk.PipelineStageFlags {
			.COLOR_ATTACHMENT_OUTPUT,
		},
		commandBufferCount   = 1,
		pCommandBuffers      = &renderer._command_buffer.buffer,
		signalSemaphoreCount = 1,
		pSignalSemaphores    = &renderer._sync_object.render_finished_semaphore,
	}

	if vk.QueueSubmit(
		   renderer._device.graphics_queue,
		   1,
		   &submit_info,
		   renderer._sync_object.in_flight_fence,
	   ) !=
	   .SUCCESS {
		panic("failed to submit draw command buffer")
	}

	present_info := vk.PresentInfoKHR {
		sType              = .PRESENT_INFO_KHR,
		waitSemaphoreCount = 1,
		pWaitSemaphores    = &renderer._sync_object.render_finished_semaphore,
		swapchainCount     = 1,
		pSwapchains        = &renderer._swap_chain.swap_chain,
		pImageIndices      = &image_index,
	}

	result = vk.QueuePresentKHR(renderer._device.present_queue, &present_info)
	if result != vk.Result.SUCCESS {
		panic("failed to present swap chain image")
	}
}

shutdown_renderer :: proc(renderer: ^Renderer) {
	synchronization.destroy_sync_object(
		&renderer._sync_object,
		renderer._device.logical_device,
	)
	command.destroy_command_pool(
		&renderer._command_pool,
		renderer._device.logical_device,
	)
	framebuffer.destroy_framebuffer_manager(&renderer._framebuffer_manager)
	pipeline.destroy_pipeline(
		renderer._device.logical_device,
		renderer._pipeline,
	)
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
