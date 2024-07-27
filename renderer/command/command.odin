package command

import "../framebuffer"
import "../pipeline"
import "../render_pass"
import "../shared"
import "../swapchain"
import vk "vendor:vulkan"

CommandPool :: struct {
	pool: vk.CommandPool,
}

CommandBuffer :: struct {
	buffer: vk.CommandBuffer,
}

create_command_pool :: proc(
	device: vk.Device,
	swap_chain: swapchain.SwapChain,
) -> CommandPool {
	command_pool := CommandPool{}

	pool_info := vk.CommandPoolCreateInfo{}
	pool_info.sType = vk.StructureType.COMMAND_POOL_CREATE_INFO
	pool_info.flags = vk.CommandPoolCreateFlags{.RESET_COMMAND_BUFFER}
	pool_info.queueFamilyIndex = swap_chain.queue_family_indices[0]

	if vk.CreateCommandPool(device, &pool_info, nil, &command_pool.pool) !=
	   vk.Result.SUCCESS {
		panic("failed to create command pool")
	}

	return command_pool
}

destroy_command_pool :: proc(pool: ^CommandPool, device: vk.Device) {
	vk.DestroyCommandPool(device, pool.pool, nil)
}

create_command_buffer :: proc(
	device: vk.Device,
	pool: CommandPool,
) -> CommandBuffer {
	command_buffer := CommandBuffer{}

	alloc_info := vk.CommandBufferAllocateInfo{}
	alloc_info.sType = vk.StructureType.COMMAND_BUFFER_ALLOCATE_INFO
	alloc_info.commandPool = pool.pool
	alloc_info.level = vk.CommandBufferLevel.PRIMARY
	alloc_info.commandBufferCount = 1

	if vk.AllocateCommandBuffers(
		   device,
		   &alloc_info,
		   &command_buffer.buffer,
	   ) !=
	   vk.Result.SUCCESS {
		panic("failed to allocate command buffers")
	}

	return command_buffer
}

record_command_buffer :: proc(
	command_buffer: CommandBuffer,
	_render_pass: render_pass.RenderPass,
	framebuffer_manager: framebuffer.FramebufferManager,
	swap_chain: swapchain.SwapChain,
	graphics_pipeline: pipeline.GraphicsPipeline,
	image_idx: u32,
) {
	begin_info := vk.CommandBufferBeginInfo{}
	begin_info.sType = vk.StructureType.COMMAND_BUFFER_BEGIN_INFO

	if vk.BeginCommandBuffer(command_buffer.buffer, &begin_info) !=
	   vk.Result.SUCCESS {
		panic("failed to begin recording command buffer")
	}

	clear_color := vk.ClearValue{}
	clear_color.color.float32[0] = 0.0
	clear_color.color.float32[1] = 0.0
	clear_color.color.float32[2] = 0.0

	render_pass_info := vk.RenderPassBeginInfo{}
	render_pass_info.sType = vk.StructureType.RENDER_PASS_BEGIN_INFO
	render_pass_info.renderPass = _render_pass.render_pass
	render_pass_info.framebuffer =
		framebuffer_manager.framebuffers[image_idx].framebuffer
	render_pass_info.renderArea.offset.x = 0
	render_pass_info.renderArea.offset.y = 0
	render_pass_info.renderArea.extent = swap_chain.extent_2d
	render_pass_info.clearValueCount = 1
	render_pass_info.pClearValues = &clear_color

	vk.CmdBeginRenderPass(
		command_buffer.buffer,
		&render_pass_info,
		vk.SubpassContents.INLINE,
	)

	vk.CmdBindPipeline(
		command_buffer.buffer,
		.GRAPHICS,
		graphics_pipeline.pipeline,
	)

	viewport := vk.Viewport {
		x        = 0.0,
		y        = 0.0,
		width    = f32(swap_chain.extent_2d.width),
		height   = f32(swap_chain.extent_2d.height),
		minDepth = 0.0,
		maxDepth = 1.0,
	}
	vk.CmdSetViewport(command_buffer.buffer, 0, 1, &viewport)

	scissor := vk.Rect2D {
		offset = {0, 0},
		extent = swap_chain.extent_2d,
	}
	vk.CmdSetScissor(command_buffer.buffer, 0, 1, &scissor)

	vk.CmdDraw(command_buffer.buffer, 3, 1, 0, 0)

	vk.CmdEndRenderPass(command_buffer.buffer)

	if vk.EndCommandBuffer(command_buffer.buffer) != .SUCCESS {
		panic("Failed to record command buffer")
	}
}
