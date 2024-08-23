package renderer

import "core:sync"

import im "../../external/odin-imgui"

Renderer :: struct {
	resources:     RendererResources,
	state:         RendererState,
	configuration: RendererConfiguration,
}

RendererResources :: struct {
	window:                Window,
	instance:              Instance,
	device:                Device,
	surface:               Surface,
	vma_allocator:         VMAAllocator,
	swap_chain:            SwapChain,
	descriptor_set_layout: DescriptorSetlayout,
	pipeline:              GraphicsPipeline,
	framebuffer_manager:   FramebufferManager,
	command_pool:          CommandPool,
	vertex_buffer:         VertexBuffer,
	index_buffer:          IndexBuffer,
	command_buffers:       CommandBuffers,
	sync_objects:          SyncObject,
	imgui:                 ImGuiState,
}

RendererState :: struct {
	current_frame:  u32,
	image_index:    u32,
	is_initialized: bool,
	mutex:          sync.Mutex,
}

RendererConfiguration :: struct {
	width:                     i32,
	height:                    i32,
	title:                     string,
	validation_layers_enabled: bool,
}

renderer_init :: proc(
	renderer: ^Renderer,
	config: RendererConfiguration,
) -> bool {
	renderer.configuration = config
	if ok := renderer_resources_init(&renderer.resources, config); ok {
		renderer.state.is_initialized = true
		log("Renderer initialization successful")

		return true
	}

	log("Renderer initialization failed", "ERROR")

	return false
}

renderer_resources_init :: proc(
	resources: ^RendererResources,
	config: RendererConfiguration,
) -> bool {
	vertices := []Vertex {
		{{-0.5, -0.5}, {1.0, 0.0, 0.0}},
		{{0.5, -0.5}, {0.0, 1.0, 0.0}},
		{{0.5, 0.5}, {0.0, 0.0, 1.0}},
		{{-0.5, 0.5}, {1.0, 1.0, 1.0}},
	}
	indices := []u32{0, 1, 2, 2, 3, 0}

	resources.window = window_create(config.width, config.height, config.title)
	resources.instance = instance_create(config.validation_layers_enabled)
	resources.device = device_create()
	resources.surface = device_surface_create(
		resources.instance,
		&resources.window,
	)
	device_pick_physical(
		&resources.device,
		resources.instance,
		resources.surface,
	)
	device_logical_create(
		&resources.device,
		resources.instance,
		resources.surface,
	)
	resources.vma_allocator = vma_init(resources.device, resources.instance)
	resources.swap_chain = swap_chain_create(
		resources.device,
		resources.surface,
		&resources.window,
	)
	resources.descriptor_set_layout = descriptor_set_layout_create(
		resources.device.logical_device,
	)
	resources.pipeline = pipeline_create(
		resources.swap_chain,
		resources.device.logical_device,
		&resources.descriptor_set_layout,
	)
	resources.framebuffer_manager = framebuffer_manager_create(
		resources.swap_chain,
		resources.pipeline.render_pass,
	)
	resources.command_pool = command_pool_create(
		resources.device.logical_device,
		resources.swap_chain,
	)
	resources.vertex_buffer = buffer_vertex_create(
		resources.device,
		vertices,
		resources.command_pool,
		resources.vma_allocator,
	)
	resources.index_buffer = buffer_index_create(
		resources.device,
		indices,
		resources.command_pool,
		resources.vma_allocator,
	)
	resources.command_buffers = command_buffers_create(
		resources.device.logical_device,
		resources.command_pool,
	)
	resources.sync_objects = sync_objects_create(
		resources.device.logical_device,
	)
	resources.imgui = imgui_init(
		resources.window.handle,
		resources.pipeline.render_pass,
		resources.device,
		resources.instance.instance,
		u32(len(resources.swap_chain.images)),
		resources.swap_chain.format.format,
		resources.command_pool.pool,
	)

	vma_print_stats(resources.vma_allocator)

	return true
}

render :: proc(renderer: ^Renderer) -> bool {
	sync.mutex_lock(&renderer.state.mutex)
	defer sync.mutex_unlock(&renderer.state.mutex)

	if !renderer.state.is_initialized {
		log("Renderer is not initialized", "ERROR")

		return false
	}

	if is_framebuffer_resized {
		swap_chain_recreate(renderer)
	}

	if !frame_prepare(renderer) do return false
	if !frame_render(renderer) do return false
	if !frame_present(renderer) do return false

	renderer.state.current_frame =
		(renderer.state.current_frame + 1) % MAX_FRAMES_IN_FLIGHT

	return true
}

frame_prepare :: proc(renderer: ^Renderer) -> bool {
	device := renderer.resources.device.logical_device
	sync_objects := renderer.resources.sync_objects
	fence := sync_objects.in_flight_fences[renderer.state.current_frame]
	semaphore :=
		sync_objects.image_available_semaphores[renderer.state.current_frame]
	swap_chain := renderer.resources.swap_chain

	if !sync_wait(device, &fence) {
		swap_chain_recreate(renderer)
		return false
	}

	image_index, ok := swap_chain_get_next_image(device, swap_chain, semaphore)
	if !ok {
		swap_chain_recreate(renderer)
		return false
	}

	renderer.state.image_index = image_index

	sync_reset_fence(device, &fence)

	return true
}

frame_render :: proc(renderer: ^Renderer) -> bool {
	device := renderer.resources.device.logical_device
	current_frame := renderer.state.current_frame
	command_buffer := renderer.resources.command_buffers.buffers[current_frame]
	sync_objects := renderer.resources.sync_objects

	command_buffer_reset(command_buffer)

	imgui_new_frame()
	im.ShowDemoWindow()

	record_ok := command_buffer_record(
		command_buffer,
		renderer.resources.framebuffer_manager,
		renderer.resources.swap_chain,
		renderer.resources.pipeline,
		renderer.resources.vertex_buffer,
		renderer.resources.index_buffer,
		{.ONE_TIME_SUBMIT},
		renderer.state.image_index,
	)
	if !record_ok do return false

	submit_ok := command_buffer_submit(
		device,
		renderer.resources.device.graphics_queue,
		&command_buffer,
		&sync_objects.image_available_semaphores[current_frame],
		&sync_objects.render_finished_semaphores[current_frame],
		sync_objects.in_flight_fences[current_frame],
	)
	if !submit_ok do return false

	return true
}


frame_present :: proc(renderer: ^Renderer) -> bool {
	sync_objects := renderer.resources.sync_objects
	current_frame := renderer.state.current_frame

	return swap_chain_present(
		renderer.resources.device.present_queue,
		&renderer.resources.swap_chain,
		&renderer.state.image_index,
		&sync_objects.render_finished_semaphores[current_frame],
	)
}

renderer_shutdown :: proc(renderer: ^Renderer) {
	sync.mutex_lock(&renderer.state.mutex)
	defer sync.mutex_unlock(&renderer.state.mutex)

	if !renderer.state.is_initialized do return

	device_wait_idle(renderer.resources.device.logical_device)
	resources_destroy(&renderer.resources)

	renderer.state.is_initialized = false

	log("Renderer shutdown")
}

resources_destroy :: proc(resources: ^RendererResources) {
	device := resources.device.logical_device

	device_wait_idle(device)

	imgui_destroy(device, resources.imgui)
	sync_objects_destroy(&resources.sync_objects, device)
	buffer_vertex_destroy(&resources.vertex_buffer, resources.vma_allocator)
	buffer_index_destroy(&resources.index_buffer, resources.vma_allocator)
	command_pool_destroy(&resources.command_pool, device)
	framebuffer_manager_destroy(&resources.framebuffer_manager)
	pipeline_destroy(device, resources.pipeline)
	swap_chain_destroy(device, resources.swap_chain)
	descriptor_set_layout_destroy(device, resources.descriptor_set_layout)
	vma_destroy(resources.vma_allocator)
	device_logical_destroy(device)
	device_surface_destroy(
		resources.surface,
		resources.instance,
		&resources.window,
	)
	instance_destroy(resources.instance)
	window_destroy(resources.window)
}
