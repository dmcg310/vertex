package command

import "../framebuffer"
import "../imgui_manager"
import "../log"
import "../pipeline"
import "../shared"
import "../swapchain"
import "../vertexbuffer"
import vk "vendor:vulkan"

CommandPool :: struct {
	pool: vk.CommandPool,
}

CommandBuffer :: struct {
	buffers: [shared.MAX_FRAMES_IN_FLIGHT]vk.CommandBuffer,
}

create_command_pool :: proc(
	device: vk.Device,
	swap_chain: swapchain.SwapChain,
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
		log.log_fatal_with_vk_result("Failed to create command pool", result)
	}

	log.log("Vulkan command pool created")

	return command_pool
}

destroy_command_pool :: proc(pool: ^CommandPool, device: vk.Device) {
	vk.DestroyCommandPool(device, pool.pool, nil)

	log.log("Vulkan command pool destroyed")
}

create_command_buffers :: proc(
	device: vk.Device,
	pool: CommandPool,
) -> CommandBuffer {
	command_buffers := CommandBuffer{}
	alloc_info := vk.CommandBufferAllocateInfo {
		sType              = .COMMAND_BUFFER_ALLOCATE_INFO,
		commandPool        = pool.pool,
		level              = .PRIMARY,
		commandBufferCount = shared.MAX_FRAMES_IN_FLIGHT,
	}

	if result := vk.AllocateCommandBuffers(
		device,
		&alloc_info,
		&command_buffers.buffers[0],
	); result != .SUCCESS {
		log.log_fatal_with_vk_result(
			"Failed to allocate command buffers",
			result,
		)
	}

	log.log("Vulkan command buffers allocated")

	return command_buffers
}

record_command_buffer :: proc(
	command_buffer: vk.CommandBuffer,
	framebuffer_manager: framebuffer.FramebufferManager,
	swap_chain: swapchain.SwapChain,
	graphics_pipeline: pipeline.GraphicsPipeline,
	vertex_buffer: vertexbuffer.VertexBuffer,
	flags: vk.CommandBufferUsageFlags,
	image_idx: u32,
) -> bool {
	begin_info := vk.CommandBufferBeginInfo {
		sType = .COMMAND_BUFFER_BEGIN_INFO,
		flags = flags,
	}

	if result := vk.BeginCommandBuffer(command_buffer, &begin_info);
	   result != .SUCCESS {
		log.log_fatal_with_vk_result(
			"Failed to begin recording command buffer",
			result,
		)

		return false
	}

	clear_values := [2]vk.ClearValue {
		{color = {float32 = {0.0, 0.0, 0.0, 1.0}}},
		{depthStencil = {depth = 1.0, stencil = 0}},
	}

	render_pass_info := vk.RenderPassBeginInfo {
		sType = .RENDER_PASS_BEGIN_INFO,
		renderPass = graphics_pipeline._render_pass.render_pass,
		framebuffer = framebuffer_manager.framebuffers[image_idx].framebuffer,
		renderArea = {offset = {x = 0, y = 0}, extent = swap_chain.extent_2d},
		clearValueCount = len(clear_values),
		pClearValues = &clear_values[0],
	}

	vk.CmdBeginRenderPass(command_buffer, &render_pass_info, .INLINE)
	vk.CmdBindPipeline(command_buffer, .GRAPHICS, graphics_pipeline.pipeline)

	viewport := vk.Viewport {
		x        = 0.0,
		y        = 0.0,
		width    = f32(swap_chain.extent_2d.width),
		height   = f32(swap_chain.extent_2d.height),
		minDepth = 0.0,
		maxDepth = 1.0,
	}
	vk.CmdSetViewport(command_buffer, 0, 1, &viewport)

	scissor := vk.Rect2D {
		offset = {0, 0},
		extent = swap_chain.extent_2d,
	}
	vk.CmdSetScissor(command_buffer, 0, 1, &scissor)

	offsets := []vk.DeviceSize{0}
	vertex_buffers := []vk.Buffer{vertex_buffer.buffer}
	vk.CmdBindVertexBuffers(
		command_buffer,
		0,
		1,
		raw_data(vertex_buffers),
		raw_data(offsets),
	)

	vk.CmdDraw(command_buffer, u32(len(vertex_buffer.vertices)), 1, 0, 0)

	imgui_manager.render_imgui(command_buffer)

	vk.CmdEndRenderPass(command_buffer)

	if result := vk.EndCommandBuffer(command_buffer); result != .SUCCESS {
		log.log_fatal_with_vk_result("Failed to record command buffer", result)

		return false
	}

	return true
}

submit_command_buffer :: proc(
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

	if vk.QueueSubmit(queue, 1, &submit_info, fence) != .SUCCESS {
		log.log_fatal("Failed to submit draw command buffer")
		return false
	}

	return true
}

reset_command_buffer :: proc(buffer: vk.CommandBuffer) {
	vk.ResetCommandBuffer(buffer, {})
}
