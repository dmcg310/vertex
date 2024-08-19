package renderer

import im "../../external/odin-imgui"
import vk "vendor:vulkan"

Renderer :: struct {
	window:              Window,
	instance:            Instance,
	device:              Device,
	surface:             Surface,
	swap_chain:          SwapChain,
	pipeline:            GraphicsPipeline,
	framebuffer_manager: FramebufferManager,
	command_pool:        CommandPool,
	vertex_buffer:       VertexBuffer,
	index_buffer:        IndexBuffer,
	command_buffers:     CommandBuffers,
	sync_objects:        SyncObject,
	imgui:               ImGuiState,
	current_frame:       u32,
	image_index:         u32,
}

RenderContext :: struct {
	image_index:         u32,
	logical_device:      vk.Device,
	graphics_queue:      vk.Queue,
	present_queue:       vk.Queue,
	swap_chain:          SwapChain,
	command_buffer:      vk.CommandBuffer,
	vertex_buffer:       VertexBuffer,
	index_buffer:        IndexBuffer,
	fence:               vk.Fence,
	available_semaphore: vk.Semaphore,
	finished_semaphore:  vk.Semaphore,
	framebuffer_manager: FramebufferManager,
	pipeline:            GraphicsPipeline,
}

renderer_init :: proc(renderer: ^Renderer, width, height: i32, title: string) {
	vertices := []Vertex {
		{{-0.5, -0.5}, {1.0, 0.0, 0.0}},
		{{0.5, -0.5}, {0.0, 1.0, 0.0}},
		{{0.5, 0.5}, {0.0, 0.0, 1.0}},
		{{-0.5, 0.5}, {1.0, 1.0, 1.0}},
	}
	indices := []u32{0, 1, 2, 2, 3, 0}

	renderer.current_frame = 0
	renderer.window = window_create(width, height, title)
	renderer.instance = instance_create(true)
	renderer.device = device_create()
	renderer.surface = device_surface_create(
		renderer.instance,
		&renderer.window,
	)
	device_pick_physical(
		&renderer.device,
		renderer.instance.instance,
		renderer.surface.surface,
	)
	device_create_logical(
		&renderer.device,
		renderer.instance,
		renderer.surface,
	)
	renderer.swap_chain = swap_chain_create(
		renderer.device.logical_device,
		renderer.device.physical_device,
		renderer.surface.surface,
		&renderer.window,
	)
	renderer.pipeline = pipeline_create(
		renderer.swap_chain,
		renderer.device.logical_device,
	)
	renderer.framebuffer_manager = framebuffer_manager_create(
		renderer.swap_chain,
		renderer.pipeline.render_pass,
	)
	for &image_view in renderer.framebuffer_manager.swap_chain.image_views {
		framebuffer_push(&renderer.framebuffer_manager, &image_view)
	}
	renderer.command_pool = command_pool_create(
		renderer.device.logical_device,
		renderer.swap_chain,
	)
	renderer.vertex_buffer = buffer_vertex_create(
		renderer.device.logical_device,
		renderer.device.physical_device,
		vertices,
		renderer.command_pool.pool,
		renderer.device.graphics_queue,
	)
	renderer.index_buffer = buffer_index_create(
		renderer.device.logical_device,
		renderer.device.physical_device,
		indices,
		renderer.command_pool.pool,
		renderer.device.graphics_queue,
	)
	renderer.command_buffers = command_buffers_create(
		renderer.device.logical_device,
		renderer.command_pool,
	)
	renderer.sync_objects = sync_objects_create(renderer.device.logical_device)
	renderer.imgui = imgui_init(
		renderer.window.handle,
		renderer.pipeline.render_pass.render_pass,
		renderer.device.logical_device,
		renderer.device.physical_device,
		renderer.instance.instance,
		renderer.device.graphics_queue,
		renderer.device.graphics_family_index,
		u32(len(renderer.swap_chain.images)),
		renderer.swap_chain.format.format,
		renderer.command_pool.pool,
	)

	device_print_properties(renderer.device.physical_device)

	log("Renderer initialized")
}

render :: proc(renderer: ^Renderer) {
	if is_framebuffer_resized {
		is_framebuffer_resized = false
		recreate_swap_chain(renderer)
	}

	if !sync_wait(
		renderer.device.logical_device,
		&renderer.sync_objects.in_flight_fences[renderer.current_frame],
	) {
		recreate_swap_chain(renderer)
	}

	image_index, ok := swap_chain_get_next_image(
		renderer.device.logical_device,
		renderer.swap_chain.swap_chain,
		renderer.sync_objects.image_available_semaphores[renderer.current_frame],
	)
	if !ok {
		recreate_swap_chain(renderer)
	}
	renderer.image_index = image_index

	ctx := get_render_context(renderer)

	imgui_new_frame()

	im.ShowDemoWindow()

	sync_reset_fence(ctx.logical_device, &ctx.fence)
	command_buffer_reset(ctx.command_buffer)

	if !command_buffer_record(
		ctx.command_buffer,
		ctx.framebuffer_manager,
		ctx.swap_chain,
		ctx.pipeline,
		ctx.vertex_buffer,
		ctx.index_buffer,
		{.ONE_TIME_SUBMIT},
		ctx.image_index,
	) {
		return
	}

	if !command_buffer_submit(
		ctx.logical_device,
		ctx.graphics_queue,
		&ctx.command_buffer,
		&ctx.available_semaphore,
		&ctx.finished_semaphore,
		ctx.fence,
	) {
		return
	}

	if !swap_chain_present(
		ctx.present_queue,
		&ctx.swap_chain,
		&ctx.image_index,
		&ctx.finished_semaphore,
	) {
		return
	}

	renderer.current_frame =
		(renderer.current_frame + 1) % MAX_FRAMES_IN_FLIGHT
}

renderer_shutdown :: proc(renderer: ^Renderer) {
	vk.DeviceWaitIdle(renderer.device.logical_device)

	imgui_destroy(renderer.device.logical_device, renderer.imgui)
	sync_objects_destroy(
		&renderer.sync_objects,
		renderer.device.logical_device,
	)
	buffer_vertex_destroy(
		&renderer.vertex_buffer,
		renderer.device.logical_device,
	)
	buffer_index_destroy(
		&renderer.index_buffer,
		renderer.device.logical_device,
	)
	command_pool_destroy(
		&renderer.command_pool,
		renderer.device.logical_device,
	)
	framebuffer_manager_destroy(&renderer.framebuffer_manager)
	pipeline_destroy(renderer.device.logical_device, renderer.pipeline)
	swap_chain_destroy(renderer.device.logical_device, renderer.swap_chain)
	device_logical_destroy(renderer.device)
	device_surface_destroy(
		renderer.surface,
		renderer.instance,
		&renderer.window,
	)
	instance_destroy(renderer.instance)
	window_destroy(renderer.window)

	log("Renderer shutdown")
}

@(private)
get_render_context :: proc(renderer: ^Renderer) -> RenderContext {
	return RenderContext {
		logical_device = renderer.device.logical_device,
		graphics_queue = renderer.device.graphics_queue,
		present_queue = renderer.device.present_queue,
		swap_chain = renderer.swap_chain,
		command_buffer = renderer.command_buffers.buffers[renderer.current_frame],
		vertex_buffer = renderer.vertex_buffer,
		index_buffer = renderer.index_buffer,
		fence = renderer.sync_objects.in_flight_fences[renderer.current_frame],
		available_semaphore = renderer.sync_objects.image_available_semaphores[renderer.current_frame],
		finished_semaphore = renderer.sync_objects.render_finished_semaphores[renderer.current_frame],
		framebuffer_manager = renderer.framebuffer_manager,
		pipeline = renderer.pipeline,
		image_index = renderer.image_index,
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
		width, height = window_get_framebuffer_size(renderer.window)
		window_wait_events()
	}

	vk.DeviceWaitIdle(renderer.device.logical_device)

	recreation_cleanup(renderer)

	renderer.swap_chain = swap_chain_create(
		renderer.device.logical_device,
		renderer.device.physical_device,
		renderer.surface.surface,
		&renderer.window,
	)

	renderer.pipeline = pipeline_create(
		renderer.swap_chain,
		renderer.device.logical_device,
	)

	renderer.framebuffer_manager = framebuffer_manager_create(
		renderer.swap_chain,
		renderer.pipeline.render_pass,
	)
	for &image_view in renderer.framebuffer_manager.swap_chain.image_views {
		framebuffer_push(&renderer.framebuffer_manager, &image_view)
	}

	renderer.command_buffers = command_buffers_create(
		renderer.device.logical_device,
		renderer.command_pool,
	)

	log("Swap chain recreated due to window resize")
}

@(private)
recreation_cleanup :: proc(renderer: ^Renderer) {
	framebuffer_manager_destroy(&renderer.framebuffer_manager)
	swap_chain_destroy(renderer.device.logical_device, renderer.swap_chain)
	pipeline_destroy(renderer.device.logical_device, renderer.pipeline)
}
