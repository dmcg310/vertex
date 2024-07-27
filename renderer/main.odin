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

MAX_FRAMES_IN_FLIGHT :: 2

Renderer :: struct {
	_window:              window.Window,
	_instance:            instance.Instance,
	_device:              device.Device,
	_surface:             device.Surface,
	_swap_chain:          swapchain.SwapChain,
	_pipeline:            pipeline.GraphicsPipeline,
	_framebuffer_manager: framebuffer.FramebufferManager,
	_command_pool:        command.CommandPool,
	_command_buffers:     command.CommandBuffer,
	_sync_objects:        synchronization.SyncObject,
	current_frame:        u32,
}

main :: proc() {
	renderer := Renderer {
		current_frame = 0,
	}

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
	renderer._command_buffers = command.create_command_buffers(
		renderer._device.logical_device,
		renderer._command_pool,
	)
	renderer._sync_objects = synchronization.create_sync_objects(
		renderer._device.logical_device,
	)

	fmt.println("Renderer initialized")

	vk.GetPhysicalDeviceProperties(
		renderer._device.physical_device,
		&renderer._device.properties,
	)
	device.display_device_properties(renderer._device.properties)
}

/* 
* We have to define these next two procedures here because of 
* 	cyclic dependencies in swapchain and framebuffer
*/

recreate_swap_chain :: proc(renderer: ^Renderer) {
	width, height: i32 = 0, 0
	for width == 0 || height == 0 {
		width, height = window.get_framebuffer_size(renderer._window)
		window.wait_events()
	}

	vk.DeviceWaitIdle(renderer._device.logical_device)

	cleanup_swap_chain(renderer)

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

	renderer._command_buffers = command.create_command_buffers(
		renderer._device.logical_device,
		renderer._command_pool,
	)
}

cleanup_swap_chain :: proc(renderer: ^Renderer) {
	framebuffer.destroy_framebuffer_manager(&renderer._framebuffer_manager)
	pipeline.destroy_pipeline(
		renderer._device.logical_device,
		renderer._pipeline,
	)
	swapchain.destroy_swap_chain(
		renderer._device.logical_device,
		renderer._swap_chain,
	)
}

render :: proc(renderer: ^Renderer) {
	result := vk.WaitForFences(
		renderer._device.logical_device,
		1,
		&renderer._sync_objects.in_flight_fences[renderer.current_frame],
		true,
		~u64(0),
	)
	if result == vk.Result.ERROR_OUT_OF_DATE_KHR {
		recreate_swap_chain(renderer)
		return
	} else if result != vk.Result.SUCCESS && result != vk.Result.TIMEOUT {
		panic("Failed to wait for fences")
	}

	vk.ResetFences(
		renderer._device.logical_device,
		1,
		&renderer._sync_objects.in_flight_fences[renderer.current_frame],
	)

	image_index: u32
	result = vk.AcquireNextImageKHR(
		renderer._device.logical_device,
		renderer._swap_chain.swap_chain,
		~u64(0),
		renderer._sync_objects.image_available_semaphores[renderer.current_frame],
		0,
		&image_index,
	)

	if result == vk.Result.ERROR_OUT_OF_DATE_KHR {
		recreate_swap_chain(renderer)
		return
	} else if result != vk.Result.SUCCESS &&
	   result != vk.Result.SUBOPTIMAL_KHR {
		panic("Failed to acquire swap chain image")
	}

	vk.ResetCommandBuffer(
		renderer._command_buffers.buffers[renderer.current_frame],
		{},
	)

	command.record_command_buffer(
		renderer._command_buffers.buffers[renderer.current_frame],
		renderer._framebuffer_manager,
		renderer._swap_chain,
		renderer._pipeline,
		image_index,
	)

	submit_info := vk.SubmitInfo {
		sType                = .SUBMIT_INFO,
		waitSemaphoreCount   = 1,
		pWaitSemaphores      = &renderer._sync_objects.image_available_semaphores[renderer.current_frame],
		pWaitDstStageMask    = &vk.PipelineStageFlags {
			.COLOR_ATTACHMENT_OUTPUT,
		},
		commandBufferCount   = 1,
		pCommandBuffers      = &renderer._command_buffers.buffers[renderer.current_frame],
		signalSemaphoreCount = 1,
		pSignalSemaphores    = &renderer._sync_objects.render_finished_semaphores[renderer.current_frame],
	}

	if vk.QueueSubmit(
		   renderer._device.graphics_queue,
		   1,
		   &submit_info,
		   renderer._sync_objects.in_flight_fences[renderer.current_frame],
	   ) !=
	   .SUCCESS {
		panic("Failed to submit draw command buffer")
	}

	present_info := vk.PresentInfoKHR {
		sType              = .PRESENT_INFO_KHR,
		waitSemaphoreCount = 1,
		pWaitSemaphores    = &renderer._sync_objects.render_finished_semaphores[renderer.current_frame],
		swapchainCount     = 1,
		pSwapchains        = &renderer._swap_chain.swap_chain,
		pImageIndices      = &image_index,
	}

	result = vk.QueuePresentKHR(renderer._device.present_queue, &present_info)
	if result == vk.Result.ERROR_OUT_OF_DATE_KHR ||
	   result == vk.Result.SUBOPTIMAL_KHR ||
	   window.framebuffer_resized {
		window.framebuffer_resized = false
		recreate_swap_chain(renderer)
	} else if result != vk.Result.SUCCESS {
		panic("Failed to present swap chain image")
	}

	renderer.current_frame =
		(renderer.current_frame + 1) % MAX_FRAMES_IN_FLIGHT
}

shutdown_renderer :: proc(renderer: ^Renderer) {
	synchronization.destroy_sync_objects(
		&renderer._sync_objects,
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
