package renderer

import "core:math/linalg"
import "core:mem"
import "core:slice"
import "core:time"

import vk "vendor:vulkan"

Vec2 :: linalg.Vector2f32
Vec3 :: linalg.Vector3f32
Mat4 :: linalg.Matrix4x4f32

Vertex :: struct {
	pos:   Vec2,
	color: Vec3,
}

VertexBuffer :: struct {
	buffer:     vk.Buffer,
	allocation: VMAAllocation,
	vertices:   []Vertex,
}

IndexBuffer :: struct {
	buffer:     vk.Buffer,
	allocation: VMAAllocation,
	indices:    []u32,
}

UniformBufferObject :: struct {
	model:      Mat4,
	view:       Mat4,
	projection: Mat4,
}

UniformBuffer :: struct {
	buffer:     vk.Buffer,
	allocation: VMAAllocation,
	object:     UniformBufferObject,
}

UniformBuffers :: struct {
	buffers: []UniformBuffer,
}

/* VERTEX BUFFER */

buffer_vertex_create :: proc(
	device: Device,
	vertices: []Vertex,
	command_pool: CommandPool,
	vma_allocator: VMAAllocator,
) -> VertexBuffer {
	buffer_size := vk.DeviceSize(size_of(Vertex) * len(vertices))

	staging_buffer, staging_buffer_allocation := vma_buffer_create(
		vma_allocator,
		buffer_size,
		{.TRANSFER_SRC},
		.AUTO,
		{.HOST_ACCESS_SEQUENTIAL_WRITE},
	)

	mapped_data := vma_map_memory(vma_allocator, staging_buffer_allocation)
	mem.copy(mapped_data, raw_data(slice.to_bytes(vertices)), int(buffer_size))
	vma_unmap_memory(vma_allocator, staging_buffer_allocation)
	vma_flush_allocation(
		vma_allocator,
		staging_buffer_allocation,
		0,
		buffer_size,
	)

	vertex_buffer, vertex_buffer_allocation := vma_buffer_create(
		vma_allocator,
		buffer_size,
		{.TRANSFER_DST, .VERTEX_BUFFER},
		.AUTO,
		{},
	)

	buffer_copy(
		staging_buffer,
		vertex_buffer,
		buffer_size,
		device.logical_device,
		command_pool.pool,
		device.graphics_queue,
	)

	vma_buffer_destroy(
		vma_allocator,
		staging_buffer,
		staging_buffer_allocation,
	)

	log("Vulkan vertex buffer created")

	return VertexBuffer {
		buffer = vertex_buffer,
		allocation = vertex_buffer_allocation,
		vertices = vertices,
	}
}

buffer_get_vertex_binding_description :: proc(
) -> vk.VertexInputBindingDescription {
	return vk.VertexInputBindingDescription {
		binding = 0,
		stride = size_of(Vertex),
		inputRate = .VERTEX,
	}
}

buffer_get_vertex_attribute_descriptions :: proc(
) -> [2]vk.VertexInputAttributeDescription {
	return [2]vk.VertexInputAttributeDescription {
		{
			binding = 0,
			location = 0,
			format = .R32G32_SFLOAT,
			offset = u32(offset_of(Vertex, pos)),
		},
		{
			binding = 0,
			location = 1,
			format = .R32G32B32_SFLOAT,
			offset = u32(offset_of(Vertex, color)),
		},
	}
}

buffer_vertex_destroy :: proc(
	buffer: ^VertexBuffer,
	vma_allocator: VMAAllocator,
) {
	vma_buffer_destroy(vma_allocator, buffer.buffer, buffer.allocation)

	log("Vulkan vertex buffer destroyed")
}

/* INDEX BUFFER */

buffer_index_create :: proc(
	device: Device,
	indices: []u32,
	command_pool: CommandPool,
	vma_allocator: VMAAllocator,
) -> IndexBuffer {
	buffer_size := vk.DeviceSize(size_of(u32) * len(indices))

	staging_buffer, staging_buffer_allocation := vma_buffer_create(
		vma_allocator,
		buffer_size,
		{.TRANSFER_SRC},
		.AUTO,
		{.HOST_ACCESS_SEQUENTIAL_WRITE},
	)

	mapped_memory := vma_map_memory(vma_allocator, staging_buffer_allocation)
	mem.copy(
		mapped_memory,
		raw_data(slice.to_bytes(indices)),
		int(buffer_size),
	)
	vma_unmap_memory(vma_allocator, staging_buffer_allocation)
	vma_flush_allocation(
		vma_allocator,
		staging_buffer_allocation,
		0,
		buffer_size,
	)

	index_buffer, index_buffer_allocation := vma_buffer_create(
		vma_allocator,
		buffer_size,
		{.TRANSFER_DST, .INDEX_BUFFER},
		.GPU_ONLY,
		{},
	)

	buffer_copy(
		staging_buffer,
		index_buffer,
		buffer_size,
		device.logical_device,
		command_pool.pool,
		device.graphics_queue,
	)

	vma_buffer_destroy(
		vma_allocator,
		staging_buffer,
		staging_buffer_allocation,
	)

	log("Vulkan index buffer created")

	return IndexBuffer {
		buffer = index_buffer,
		allocation = index_buffer_allocation,
		indices = indices,
	}
}

buffer_index_destroy :: proc(
	buffer: ^IndexBuffer,
	vma_allocator: VMAAllocator,
) {
	vma_buffer_destroy(vma_allocator, buffer.buffer, buffer.allocation)

	log("Vulkan index buffer destroyed")
}

/* UNIFORM BUFFER */

buffer_uniforms_create :: proc(
	device: Device,
	vma_allocator: VMAAllocator,
) -> UniformBuffers {
	buffer_size := vk.DeviceSize(size_of(UniformBufferObject))

	buffers := make(
		[]UniformBuffer,
		MAX_FRAMES_IN_FLIGHT,
		context.temp_allocator,
	)

	for i in 0 ..< MAX_FRAMES_IN_FLIGHT {
		buffer, allocation := vma_buffer_create(
			vma_allocator,
			buffer_size,
			{.UNIFORM_BUFFER},
			.AUTO,
			{.HOST_ACCESS_SEQUENTIAL_WRITE},
		)

		mapped_memory := vma_map_memory(vma_allocator, allocation)

		temp := cast(^UniformBufferObject)mapped_memory
		buffers[i] = UniformBuffer {
			buffer     = buffer,
			allocation = allocation,
			object     = temp^,
		}

		vma_unmap_memory(vma_allocator, allocation)
		vma_flush_allocation(vma_allocator, allocation, 0, buffer_size)
	}

	log("Vulkan uniform buffers created")

	return UniformBuffers{buffers}
}

buffer_uniforms_update :: proc(
	uniform_buffers: ^UniformBuffers,
	current_frame: u32,
	swap_chain_extent: vk.Extent2D,
) {
	start_time := time.now()
	time_elapsed := time.duration_seconds(time.since(start_time))

	ubo := &uniform_buffers.buffers[current_frame].object
	ubo.model = linalg.matrix4_rotate_f32(
		f32(time_elapsed * linalg.to_radians(90.0)),
		Vec3{0, 0, 1},
	)

	ubo.view = linalg.matrix4_look_at_f32(
		Vec3{2, 2, 2}, // Eye position
		Vec3{0, 0, 0}, // Center position
		Vec3{0, 0, 1}, // Up vector
	)

	aspect_ratio :=
		f32(swap_chain_extent.width) / f32(swap_chain_extent.height)

	ubo.projection = linalg.matrix4_perspective_f32(
		f32(linalg.to_radians(45.0)), // Field of view in radians
		aspect_ratio, // Aspect ratio
		0.1, // Near plane
		10.0, // Far plane
	)

	ubo.projection[1][1] *= -1
}

buffer_uniforms_destroy :: proc(
	buffers: ^UniformBuffers,
	vma_allocator: VMAAllocator,
) {
	for i in 0 ..< MAX_FRAMES_IN_FLIGHT {
		log("Destorying a uniform buffer", "DEBUG")
		vma_buffer_destroy(
			vma_allocator,
			buffers.buffers[i].buffer,
			buffers.buffers[i].allocation,
		)
	}

	log("Vulkan uniform buffers destroyed")
}

@(private = "file")
buffer_copy :: proc(
	src_buffer: vk.Buffer,
	dst_buffer: vk.Buffer,
	size: vk.DeviceSize,
	device: vk.Device,
	command_pool: vk.CommandPool,
	graphics_queue: vk.Queue,
) {
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

	copy_region := vk.BufferCopy {
		srcOffset = 0,
		dstOffset = 0,
		size      = size,
	}

	vk.CmdCopyBuffer(command_buffer, src_buffer, dst_buffer, 1, &copy_region)
	vk.EndCommandBuffer(command_buffer)

	submit_info := vk.SubmitInfo {
		sType              = .SUBMIT_INFO,
		commandBufferCount = 1,
		pCommandBuffers    = &command_buffer,
	}

	if result := vk.QueueSubmit(graphics_queue, 1, &submit_info, 0);
	   result != .SUCCESS {
		log_fatal_with_vk_result("Failed to submit copy command", result)
	}

	vk.QueueWaitIdle(graphics_queue)

	vk.FreeCommandBuffers(device, command_pool, 1, &command_buffer)
}
