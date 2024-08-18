package memory

import "../log"
import "../vertexbuffer"
import odin_mem "core:mem"
import "core:slice"
import vk "vendor:vulkan"

allocate_vertex_buffer_memory :: proc(
	logical_device: vk.Device,
	physical_device: vk.PhysicalDevice,
	vertex_buffer: ^vertexbuffer.VertexBuffer,
) {
	memory_requirements := vk.MemoryRequirements{}

	vk.GetBufferMemoryRequirements(
		logical_device,
		vertex_buffer.buffer,
		&memory_requirements,
	)

	memory_type_index := find_memory_type(
		physical_device,
		memory_requirements.memoryTypeBits,
		{.HOST_VISIBLE, .HOST_COHERENT},
	)

	memory_allocate_info := vk.MemoryAllocateInfo {
		sType           = .MEMORY_ALLOCATE_INFO,
		allocationSize  = memory_requirements.size,
		memoryTypeIndex = memory_type_index,
	}

	if result := vk.AllocateMemory(
		logical_device,
		&memory_allocate_info,
		nil,
		&vertex_buffer.memory,
	); result != .SUCCESS {
		log.log_fatal_with_vk_result(
			"Failed to allocate vertex buffer memory",
			result,
		)
	}

	vk.BindBufferMemory(
		logical_device,
		vertex_buffer.buffer,
		vertex_buffer.memory,
		0,
	)

	data := slice.to_bytes(vertex_buffer.vertices)
	mapped_memory: rawptr

	if result := vk.MapMemory(
		logical_device,
		vertex_buffer.memory,
		0,
		vk.DeviceSize(len(data)),
		nil,
		&mapped_memory,
	); result != .SUCCESS {
		log.log_fatal_with_vk_result("Failed to map memory", result)
	}

	odin_mem.copy(mapped_memory, raw_data(data), len(data))

	vk.UnmapMemory(logical_device, vertex_buffer.memory)
}

@(private)
find_memory_type :: proc(
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

	log.log_fatal("Failed to find suitable memory type")

	return 0
}
