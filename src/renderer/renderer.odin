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
	result := vk.WaitForFences(
		renderer._device.logical_device,
		1,
		&renderer._sync_objects.in_flight_fences[renderer.current_frame],
		true,
		~u64(0),
	)

	if result == .ERROR_OUT_OF_DATE_KHR {
		recreate_swap_chain(renderer)
		return
	} else if result != .SUCCESS && result != .TIMEOUT {
		log.log_fatal("Failed to wait for fences")
	}

	image_index: u32
	result = vk.AcquireNextImageKHR(
		renderer._device.logical_device,
		renderer._swap_chain.swap_chain,
		~u64(0),
		renderer._sync_objects.image_available_semaphores[renderer.current_frame],
		0,
		&image_index,
	)

	if result == .ERROR_OUT_OF_DATE_KHR {
		recreate_swap_chain(renderer)
		return
	} else if result != .SUCCESS && result != .SUBOPTIMAL_KHR {
		log.log_fatal("Failed to acquire swap chain image")
	}

	imgui_manager.new_imgui_frame()

	im.ShowDemoWindow()

	vk.ResetFences(
		renderer._device.logical_device,
		1,
		&renderer._sync_objects.in_flight_fences[renderer.current_frame],
	)

	vk.ResetCommandBuffer(
		renderer._command_buffers.buffers[renderer.current_frame],
		{},
	)

	begin_info := vk.CommandBufferBeginInfo {
		sType = .COMMAND_BUFFER_BEGIN_INFO,
		flags = {.ONE_TIME_SUBMIT},
	}

	if vk.BeginCommandBuffer(
		   renderer._command_buffers.buffers[renderer.current_frame],
		   &begin_info,
	   ) !=
	   .SUCCESS {
		log.log_fatal("Failed to begin recording command buffer")
	}

	render_pass_info := vk.RenderPassBeginInfo {
		sType = .RENDER_PASS_BEGIN_INFO,
		renderPass = renderer._pipeline._render_pass.render_pass,
		framebuffer = renderer._framebuffer_manager.framebuffers[image_index].framebuffer,
		renderArea = vk.Rect2D {
			offset = {0, 0},
			extent = renderer._swap_chain.extent_2d,
		},
	}

	clear_values := [2]vk.ClearValue {
		{color = {float32 = {0.0, 0.0, 0.0, 1.0}}},
		{depthStencil = {depth = 1.0, stencil = 0}},
	}
	render_pass_info.clearValueCount = 2
	render_pass_info.pClearValues = &clear_values[0]

	vk.CmdBeginRenderPass(
		renderer._command_buffers.buffers[renderer.current_frame],
		&render_pass_info,
		.INLINE,
	)

	vk.CmdBindPipeline(
		renderer._command_buffers.buffers[renderer.current_frame],
		.GRAPHICS,
		renderer._pipeline.pipeline,
	)

	viewport := vk.Viewport {
		x        = 0.0,
		y        = 0.0,
		width    = f32(renderer._swap_chain.extent_2d.width),
		height   = f32(renderer._swap_chain.extent_2d.height),
		minDepth = 0.0,
		maxDepth = 1.0,
	}
	vk.CmdSetViewport(
		renderer._command_buffers.buffers[renderer.current_frame],
		0,
		1,
		&viewport,
	)

	scissor := vk.Rect2D {
		offset = {0, 0},
		extent = renderer._swap_chain.extent_2d,
	}
	vk.CmdSetScissor(
		renderer._command_buffers.buffers[renderer.current_frame],
		0,
		1,
		&scissor,
	)

	vk.CmdDraw(
		renderer._command_buffers.buffers[renderer.current_frame],
		3,
		1,
		0,
		0,
	)

	imgui_manager.render_imgui(
		renderer._command_buffers.buffers[renderer.current_frame],
	)

	vk.CmdEndRenderPass(
		renderer._command_buffers.buffers[renderer.current_frame],
	)

	if vk.EndCommandBuffer(
		   renderer._command_buffers.buffers[renderer.current_frame],
	   ) !=
	   .SUCCESS {
		log.log_fatal("Failed to record command buffer")
	}

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
		log.log_fatal("Failed to submit draw command buffer")
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
	if result == .ERROR_OUT_OF_DATE_KHR ||
	   result == .SUBOPTIMAL_KHR ||
	   window.framebuffer_resized {
		window.framebuffer_resized = false
		recreate_swap_chain(renderer)
	} else if result != .SUCCESS {
		log.log_fatal("Failed to present swap chain image")
	}

	imgui_manager.update_imgui_platform_windows()

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
