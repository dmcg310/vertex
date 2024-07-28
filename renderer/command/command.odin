package command

import "../framebuffer"
import "../log"
import "../pipeline"
import "../render_pass"
import "../shared"
import "../swapchain"
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

	pool_info := vk.CommandPoolCreateInfo{}
	pool_info.sType = vk.StructureType.COMMAND_POOL_CREATE_INFO
	pool_info.flags = vk.CommandPoolCreateFlags{.RESET_COMMAND_BUFFER}
	pool_info.queueFamilyIndex = u32(
		swap_chain.queue_family_indices.data[.Graphics],
	)

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

	alloc_info := vk.CommandBufferAllocateInfo{}
	alloc_info.sType = vk.StructureType.COMMAND_BUFFER_ALLOCATE_INFO
	alloc_info.commandPool = pool.pool
	alloc_info.level = vk.CommandBufferLevel.PRIMARY
	alloc_info.commandBufferCount = shared.MAX_FRAMES_IN_FLIGHT

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
	image_idx: u32,
) {
	begin_info := vk.CommandBufferBeginInfo{}
	begin_info.sType = vk.StructureType.COMMAND_BUFFER_BEGIN_INFO

	if result := vk.BeginCommandBuffer(command_buffer, &begin_info);
	   result != .SUCCESS {
		log.log_fatal_with_vk_result(
			"Failed to begin recording command buffer",
			result,
		)
	}

	clear_color := vk.ClearValue {
		color = {float32 = {0.1, 0.1, 0.1, 1.0}},
	}

	render_pass_info := vk.RenderPassBeginInfo{}
	render_pass_info.sType = vk.StructureType.RENDER_PASS_BEGIN_INFO
	render_pass_info.renderPass = graphics_pipeline._render_pass.render_pass
	render_pass_info.framebuffer =
		framebuffer_manager.framebuffers[image_idx].framebuffer
	render_pass_info.renderArea.offset.x = 0
	render_pass_info.renderArea.offset.y = 0
	render_pass_info.renderArea.extent = swap_chain.extent_2d
	render_pass_info.clearValueCount = 1
	render_pass_info.pClearValues = &clear_color

	vk.CmdBeginRenderPass(
		command_buffer,
		&render_pass_info,
		vk.SubpassContents.INLINE,
	)

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

	vk.CmdDraw(command_buffer, 3, 1, 0, 0)

	vk.CmdEndRenderPass(command_buffer)

	if result := vk.EndCommandBuffer(command_buffer); result != .SUCCESS {
		log.log_fatal_with_vk_result("Failed to record command buffer", result)
	}
}
