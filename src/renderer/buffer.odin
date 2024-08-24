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
	pos:      Vec2,
	color:    Vec3,
	texCoord: Vec2,
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
) -> [3]vk.VertexInputAttributeDescription {
	return [3]vk.VertexInputAttributeDescription {
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
		{
			binding = 0,
			location = 2,
			format = .R32G32_SFLOAT,
			offset = u32(offset_of(Vertex, texCoord)),
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
	vma_allocator: VMAAllocator,
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
		f32(linalg.to_radians(45.0)),
		aspect_ratio,
		0.1,
		10.0,
	)

	ubo.projection[1][1] *= -1

	mapped_data := vma_map_memory(
		vma_allocator,
		uniform_buffers.buffers[current_frame].allocation,
	)
	mem.copy(mapped_data, ubo, size_of(UniformBufferObject))
	vma_unmap_memory(
		vma_allocator,
		uniform_buffers.buffers[current_frame].allocation,
	)
}

buffer_uniforms_destroy :: proc(
	buffers: ^UniformBuffers,
	vma_allocator: VMAAllocator,
) {
	for i in 0 ..< MAX_FRAMES_IN_FLIGHT {
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
	command_buffer := command_begin_single_time(device, command_pool)

	copy_region := vk.BufferCopy {
		srcOffset = 0,
		dstOffset = 0,
		size      = size,
	}
	vk.CmdCopyBuffer(command_buffer, src_buffer, dst_buffer, 1, &copy_region)

	command_end_single_time(
		device,
		command_pool,
		graphics_queue,
		&command_buffer,
	)
}
