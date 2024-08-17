package renderer

import im "../../external/odin-imgui"
import "../command"
import "../device"
import "../framebuffer"
import "../imgui_manager"
import "../instance"
import "../log"
import "../pipeline"
import "../shared"
import "../swapchain"
import "../synchronization"
import "../window"
import vk "vendor:vulkan"

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
	_imgui:               imgui_manager.ImGuiState,
	current_frame:        u32,
}

RenderContext :: struct {
	image_index:         u32,
	logical_device:      vk.Device,
	graphics_queue:      vk.Queue,
	present_queue:       vk.Queue,
	swap_chain:          swapchain.SwapChain,
	buffer:              vk.CommandBuffer,
	fence:               vk.Fence,
	available_semaphore: vk.Semaphore,
	finished_semaphore:  vk.Semaphore,
	framebuffer_manager: framebuffer.FramebufferManager,
	pipeline:            pipeline.GraphicsPipeline,
}

init_renderer :: proc(renderer: ^Renderer, width, height: i32, title: string) {
	renderer.current_frame = 0
	renderer._window = window.init_window(width, height, title)
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
	renderer._imgui = imgui_manager.init_imgui(
		renderer._window.handle,
		renderer._pipeline._render_pass.render_pass,
		renderer._device.logical_device,
		renderer._device.physical_device,
		renderer._instance.instance,
		renderer._device.graphics_queue,
		renderer._device.graphics_family_index,
		u32(len(renderer._swap_chain.images)),
		renderer._swap_chain.format.format,
		renderer._command_pool.pool,
	)

	log.log("Renderer initialized")

	vk.GetPhysicalDeviceProperties(
		renderer._device.physical_device,
		&renderer._device.properties,
	)
	log.log(device.device_properties_to_string(renderer._device.properties))
}

render :: proc(renderer: ^Renderer) {
	ctx := get_render_context(renderer)

	if !synchronization.wait_for_sync(ctx.logical_device, &ctx.fence) {
		recreate_swap_chain(renderer)
	}

	if _, ok := swapchain.get_next_image(
		ctx.logical_device,
		ctx.swap_chain.swap_chain,
		ctx.available_semaphore,
	); !ok {
		recreate_swap_chain(renderer)
	}

	imgui_manager.new_imgui_frame()

	im.ShowDemoWindow()

	synchronization.reset_fence(ctx.logical_device, &ctx.fence)
	command.reset_command_buffer(ctx.buffer)

	if !command.record_command_buffer(
		ctx.buffer,
		ctx.framebuffer_manager,
		ctx.swap_chain,
		ctx.pipeline,
		{.ONE_TIME_SUBMIT},
		ctx.image_index,
	) {
		return
	}

	if !command.submit_command_buffer(
		ctx.logical_device,
		ctx.graphics_queue,
		&ctx.buffer,
		&ctx.available_semaphore,
		&ctx.finished_semaphore,
		ctx.fence,
	) {
		return
	}

	if !swapchain.present_image(
		ctx.present_queue,
		&ctx.swap_chain,
		&ctx.image_index,
		&ctx.finished_semaphore,
	) {
		return
	}

	renderer.current_frame =
		(renderer.current_frame + 1) % shared.MAX_FRAMES_IN_FLIGHT
}

shutdown_renderer :: proc(renderer: ^Renderer) {
	vk.DeviceWaitIdle(renderer._device.logical_device)

	imgui_manager.destroy_imgui(
		renderer._device.logical_device,
		renderer._imgui,
	)
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

	log.log("Renderer shutdown")
}

@(private)
get_render_context :: proc(renderer: ^Renderer) -> RenderContext {
	return RenderContext {
		image_index = 0,
		logical_device = renderer._device.logical_device,
		graphics_queue = renderer._device.graphics_queue,
		present_queue = renderer._device.present_queue,
		swap_chain = renderer._swap_chain,
		buffer = renderer._command_buffers.buffers[renderer.current_frame],
		fence = renderer._sync_objects.in_flight_fences[renderer.current_frame],
		available_semaphore = renderer._sync_objects.image_available_semaphores[renderer.current_frame],
		finished_semaphore = renderer._sync_objects.render_finished_semaphores[renderer.current_frame],
		framebuffer_manager = renderer._framebuffer_manager,
		pipeline = renderer._pipeline,
	}
}

/* 
* We have to define these next two procedures here because of 
* 	cyclic dependencies in swapchain and framebuffer
*/

@(private)
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

	log.log("Swap chain recreated due to window resize")
}

@(private)
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
