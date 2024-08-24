package renderer

import vk "vendor:vulkan"

CommandPool :: struct {
	pool: vk.CommandPool,
}

CommandBuffers :: struct {
	buffers: [MAX_FRAMES_IN_FLIGHT]vk.CommandBuffer,
}

command_pool_create :: proc(
	device: vk.Device,
	swap_chain: SwapChain,
) -> CommandPool {
	command_pool := CommandPool{}
	pool_info := vk.CommandPoolCreateInfo {
		sType            = .COMMAND_POOL_CREATE_INFO,
		flags            = {.RESET_COMMAND_BUFFER},
		queueFamilyIndex = u32(
			swap_chain.queue_family_indices.data[.Graphics],
		),
	}

	if result := vk.CreateCommandPool(
		device,
		&pool_info,
		nil,
		&command_pool.pool,
	); result != .SUCCESS {
		log_fatal_with_vk_result("Failed to create command pool", result)
	}

	log("Vulkan command pool created")

	return command_pool
}

command_pool_destroy :: proc(pool: ^CommandPool, device: vk.Device) {
	vk.DestroyCommandPool(device, pool.pool, nil)

	log("Vulkan command pool destroyed")
}

command_buffers_create :: proc(
	device: vk.Device,
	pool: CommandPool,
) -> CommandBuffers {
	command_buffers := CommandBuffers{}
	alloc_info := vk.CommandBufferAllocateInfo {
		sType              = .COMMAND_BUFFER_ALLOCATE_INFO,
		commandPool        = pool.pool,
		level              = .PRIMARY,
		commandBufferCount = MAX_FRAMES_IN_FLIGHT,
	}

	if result := vk.AllocateCommandBuffers(
		device,
		&alloc_info,
		&command_buffers.buffers[0],
	); result != .SUCCESS {
		log_fatal_with_vk_result("Failed to allocate command buffers", result)
	}

	log("Vulkan command buffers allocated")

	return command_buffers
}

command_buffer_record :: proc(
	command_buffers: vk.CommandBuffer,
	framebuffer_manager: FramebufferManager,
	swap_chain: SwapChain,
	graphics_pipeline: GraphicsPipeline,
	vertex_buffer: VertexBuffer,
	index_buffer: IndexBuffer,
	flags: vk.CommandBufferUsageFlags,
	image_idx: u32,
	current_frame: u32,
	descriptor_sets: DescriptorSets,
) -> bool {
	begin_info := vk.CommandBufferBeginInfo {
		sType = .COMMAND_BUFFER_BEGIN_INFO,
		flags = flags,
	}

	if result := vk.BeginCommandBuffer(command_buffers, &begin_info);
	   result != .SUCCESS {
		log_fatal_with_vk_result(
			"Failed to begin recording command buffer",
			result,
		)

		return false
	}

	clear_values: []vk.ClearValue = {
		{color = {float32 = {0.0, 0.0, 0.0, 1.0}}},
		{depthStencil = {depth = 1.0, stencil = 0}},
	}

	render_pass_info := vk.RenderPassBeginInfo {
		sType = .RENDER_PASS_BEGIN_INFO,
		renderPass = graphics_pipeline.render_pass,
		framebuffer = framebuffer_manager.framebuffers[image_idx].framebuffer,
		renderArea = {offset = {x = 0, y = 0}, extent = swap_chain.extent_2d},
		clearValueCount = u32(len(clear_values)),
		pClearValues = raw_data(clear_values),
	}

	vk.CmdBeginRenderPass(command_buffers, &render_pass_info, .INLINE)
	vk.CmdBindPipeline(command_buffers, .GRAPHICS, graphics_pipeline.pipeline)

	viewport := vk.Viewport {
		x        = 0.0,
		y        = 0.0,
		width    = f32(swap_chain.extent_2d.width),
		height   = f32(swap_chain.extent_2d.height),
		minDepth = 0.0,
		maxDepth = 1.0,
	}
	vk.CmdSetViewport(command_buffers, 0, 1, &viewport)

	scissor := vk.Rect2D {
		offset = {0, 0},
		extent = swap_chain.extent_2d,
	}
	vk.CmdSetScissor(command_buffers, 0, 1, &scissor)

	offsets := []vk.DeviceSize{0}

	vertex_buffers := []vk.Buffer{vertex_buffer.buffer}
	vk.CmdBindVertexBuffers(
		command_buffers,
		0,
		1,
		raw_data(vertex_buffers),
		raw_data(offsets),
	)

	vk.CmdBindIndexBuffer(command_buffers, index_buffer.buffer, 0, .UINT32)

	vk.CmdBindDescriptorSets(
		command_buffers,
		.GRAPHICS,
		graphics_pipeline.pipeline_layout,
		0,
		1,
		&descriptor_sets[current_frame],
		0,
		nil,
	)

	vk.CmdDrawIndexed(
		command_buffers,
		u32(len(index_buffer.indices)),
		1,
		0,
		0,
		0,
	)

	imgui_render(command_buffers)

	vk.CmdEndRenderPass(command_buffers)

	if result := vk.EndCommandBuffer(command_buffers); result != .SUCCESS {
		log_fatal_with_vk_result("Failed to record command buffer", result)

		return false
	}

	return true
}

command_buffer_submit :: proc(
	device: vk.Device,
	queue: vk.Queue,
	buffer: ^vk.CommandBuffer,
	wait_semaphore: ^vk.Semaphore,
	signal_semaphore: ^vk.Semaphore,
	fence: vk.Fence,
) -> bool {
	submit_info := vk.SubmitInfo {
		sType                = .SUBMIT_INFO,
		waitSemaphoreCount   = 1,
		pWaitSemaphores      = wait_semaphore,
		pWaitDstStageMask    = &vk.PipelineStageFlags {
			.COLOR_ATTACHMENT_OUTPUT,
		},
		commandBufferCount   = 1,
		pCommandBuffers      = buffer,
		signalSemaphoreCount = 1,
		pSignalSemaphores    = signal_semaphore,
	}

	if result := vk.QueueSubmit(queue, 1, &submit_info, fence);
	   result != .SUCCESS {
		log_fatal_with_vk_result(
			"Failed to submit draw command buffer",
			result,
		)
		return false
	}

	return true
}

command_buffer_reset :: proc(buffer: vk.CommandBuffer) {
	vk.ResetCommandBuffer(buffer, {})
}

command_begin_single_time :: proc(
	device: vk.Device,
	command_pool: vk.CommandPool,
) -> vk.CommandBuffer {
	allocate_info := vk.CommandBufferAllocateInfo {
		sType              = .COMMAND_BUFFER_ALLOCATE_INFO,
		level              = .PRIMARY,
		commandPool        = command_pool,
		commandBufferCount = 1,
	}

	command_buffer := vk.CommandBuffer{}
	if result := vk.AllocateCommandBuffers(
		device,
		&allocate_info,
		&command_buffer,
	); result != .SUCCESS {
		log_fatal_with_vk_result("Failed to allocate command buffer", result)
	}

	begin_info := vk.CommandBufferBeginInfo {
		sType = .COMMAND_BUFFER_BEGIN_INFO,
		flags = {.ONE_TIME_SUBMIT},
	}

	if result := vk.BeginCommandBuffer(command_buffer, &begin_info);
	   result != .SUCCESS {
		log_fatal_with_vk_result(
			"Failed to begin recording command buffer",
			result,
		)
	}

	return command_buffer
}

command_end_single_time :: proc(
	device: vk.Device,
	command_pool: vk.CommandPool,
	graphics_queue: vk.Queue,
	command_buffer: ^vk.CommandBuffer,
) {
	vk.EndCommandBuffer(command_buffer^)

	submit_info := vk.SubmitInfo {
		sType              = .SUBMIT_INFO,
		commandBufferCount = 1,
		pCommandBuffers    = command_buffer,
	}

	if result := vk.QueueSubmit(graphics_queue, 1, &submit_info, 0);
	   result != .SUCCESS {
		log_fatal_with_vk_result("Failed to submit copy command", result)
	}

	vk.QueueWaitIdle(graphics_queue)

	vk.FreeCommandBuffers(device, command_pool, 1, command_buffer)
}
