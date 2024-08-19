package renderer

import "core:math/linalg"
import "core:mem"
import "core:slice"

import vk "vendor:vulkan"

Vec2 :: linalg.Vector2f32
Vec3 :: linalg.Vector3f32

Vertex :: struct {
	pos:   Vec2,
	color: Vec3,
}

VertexBuffer :: struct {
	buffer:   vk.Buffer,
	memory:   vk.DeviceMemory,
	vertices: []Vertex,
}

IndexBuffer :: struct {
	buffer:  vk.Buffer,
	memory:  vk.DeviceMemory,
	indices: []u32,
}

/* VERTEX BUFFER */

buffer_vertex_create :: proc(
	logical_device: vk.Device,
	physical_device: vk.PhysicalDevice,
	vertices: []Vertex,
	command_pool: vk.CommandPool,
	graphics_queue: vk.Queue,
) -> VertexBuffer {
	buffer_size := vk.DeviceSize(size_of(Vertex) * len(vertices))

	staging_buffer, staging_buffer_memory := buffer_create(
		logical_device,
		physical_device,
		buffer_size,
		{.TRANSFER_SRC},
		{.HOST_VISIBLE, .HOST_COHERENT},
	)

	mapped_memory: rawptr
	data := slice.to_bytes(vertices)

	if result := vk.MapMemory(
		logical_device,
		staging_buffer_memory,
		0,
		buffer_size,
		nil,
		&mapped_memory,
	); result != .SUCCESS {
		log_fatal_with_vk_result("Failed to map memory", result)
	}

	mem.copy(mapped_memory, raw_data(data), int(buffer_size))
	vk.UnmapMemory(logical_device, staging_buffer_memory)

	vertex_buffer, vertex_buffer_memory := buffer_create(
		logical_device,
		physical_device,
		buffer_size,
		{.TRANSFER_DST, .VERTEX_BUFFER},
		{.DEVICE_LOCAL},
	)

	buffer_copy(
		staging_buffer,
		vertex_buffer,
		buffer_size,
		logical_device,
		command_pool,
		graphics_queue,
	)

	vk.DestroyBuffer(logical_device, staging_buffer, nil)
	vk.FreeMemory(logical_device, staging_buffer_memory, nil)

	log("Vulkan vertex buffer created")

	return VertexBuffer {
		buffer = vertex_buffer,
		memory = vertex_buffer_memory,
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
	logical_device: vk.Device,
) {
	vk.DestroyBuffer(logical_device, buffer.buffer, nil)
	vk.FreeMemory(logical_device, buffer.memory, nil)

	log("Vulkan vertex buffer destroyed")
}

/* INDEX BUFFER */

buffer_index_create :: proc(
	logical_device: vk.Device,
	physical_device: vk.PhysicalDevice,
	indices: []u32,
	command_pool: vk.CommandPool,
	graphics_queue: vk.Queue,
) -> IndexBuffer {
	buffer_size := vk.DeviceSize(size_of(u32) * len(indices))

	staging_buffer, staging_buffer_memory := buffer_create(
		logical_device,
		physical_device,
		buffer_size,
		{.TRANSFER_SRC},
		{.HOST_VISIBLE, .HOST_COHERENT},
	)

	mapped_memory: rawptr
	data := slice.to_bytes(indices)

	if result := vk.MapMemory(
		logical_device,
		staging_buffer_memory,
		0,
		buffer_size,
		nil,
		&mapped_memory,
	); result != .SUCCESS {
		log_fatal_with_vk_result("Failed to map memory", result)
	}

	mem.copy(mapped_memory, raw_data(data), int(buffer_size))
	vk.UnmapMemory(logical_device, staging_buffer_memory)

	index_buffer, index_buffer_memory := buffer_create(
		logical_device,
		physical_device,
		buffer_size,
		{.TRANSFER_DST, .INDEX_BUFFER},
		{.DEVICE_LOCAL},
	)

	buffer_copy(
		staging_buffer,
		index_buffer,
		buffer_size,
		logical_device,
		command_pool,
		graphics_queue,
	)

	vk.DestroyBuffer(logical_device, staging_buffer, nil)
	vk.FreeMemory(logical_device, staging_buffer_memory, nil)

	log("Vulkan index buffer created")

	return IndexBuffer {
		buffer = index_buffer,
		memory = index_buffer_memory,
		indices = indices,
	}
}

buffer_index_destroy :: proc(buffer: ^IndexBuffer, logical_device: vk.Device) {
	vk.DestroyBuffer(logical_device, buffer.buffer, nil)
	vk.FreeMemory(logical_device, buffer.memory, nil)

	log("Vulkan index buffer destroyed")
}

@(private = "file")
buffer_create :: proc(
	logical_device: vk.Device,
	physical_device: vk.PhysicalDevice,
	size: vk.DeviceSize,
	usage: vk.BufferUsageFlags,
	properties: vk.MemoryPropertyFlags,
) -> (
	buffer: vk.Buffer,
	buffer_memory: vk.DeviceMemory,
) {
	_buffer := vk.Buffer{}
	_buffer_memory := vk.DeviceMemory{}

	buffer_info := vk.BufferCreateInfo {
		sType       = .BUFFER_CREATE_INFO,
		size        = size,
		usage       = usage,
		sharingMode = .EXCLUSIVE,
	}

	if result := vk.CreateBuffer(logical_device, &buffer_info, nil, &_buffer);
	   result != .SUCCESS {
		log_fatal_with_vk_result("Failed to create buffer", result)
	}

	memory_requirements := vk.MemoryRequirements{}
	vk.GetBufferMemoryRequirements(
		logical_device,
		_buffer,
		&memory_requirements,
	)

	allocate_info := vk.MemoryAllocateInfo {
		sType           = .MEMORY_ALLOCATE_INFO,
		allocationSize  = memory_requirements.size,
		memoryTypeIndex = buffer_find_memory_type(
			physical_device,
			memory_requirements.memoryTypeBits,
			properties,
		),
	}

	if result := vk.AllocateMemory(
		logical_device,
		&allocate_info,
		nil,
		&_buffer_memory,
	); result != .SUCCESS {
		log_fatal_with_vk_result("Failed to allocate buffer memory", result)
	}

	vk.BindBufferMemory(logical_device, _buffer, _buffer_memory, 0)

	return _buffer, _buffer_memory
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

@(private)
buffer_find_memory_type :: proc(
	physical_device: vk.PhysicalDevice,
	type_filter: u32,
	properties: vk.MemoryPropertyFlags,
) -> u32 {
	memory_properties := vk.PhysicalDeviceMemoryProperties{}
	vk.GetPhysicalDeviceMemoryProperties(physical_device, &memory_properties)

	for i: u32 = 0; i < memory_properties.memoryTypeCount; i += 1 {
		if (type_filter & (1 << i) != 0) &&
		   (memory_properties.memoryTypes[i].propertyFlags & properties ==
				   properties) {
			return i
		}
	}

	log_fatal("Failed to find suitable memory type")

	return 0
}
