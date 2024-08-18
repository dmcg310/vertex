package vertexbuffer

import "../log"
import "core:math/linalg"
import vk "vendor:vulkan"

Vertex :: struct {
	pos:   linalg.Vector2f32,
	color: linalg.Vector3f32,
}

VertexBuffer :: struct {
	buffer:   vk.Buffer,
	memory:   vk.DeviceMemory,
	vertices: []Vertex,
}

get_binding_description :: proc() -> vk.VertexInputBindingDescription {
	return vk.VertexInputBindingDescription {
		binding = 0,
		stride = size_of(Vertex),
		inputRate = .VERTEX,
	}
}

get_attribute_descriptions :: proc() -> [2]vk.VertexInputAttributeDescription {
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

create_vertex_buffer :: proc(
	device: vk.Device,
	vertices: []Vertex,
) -> VertexBuffer {
	vertex_buffer := VertexBuffer{}

	buffer_info := vk.BufferCreateInfo {
		sType       = .BUFFER_CREATE_INFO,
		size        = vk.DeviceSize(size_of(Vertex) * len(vertices)),
		usage       = {.VERTEX_BUFFER},
		sharingMode = .EXCLUSIVE,
	}

	if result := vk.CreateBuffer(
		device,
		&buffer_info,
		nil,
		&vertex_buffer.buffer,
	); result != .SUCCESS {
		log.log_fatal_with_vk_result("Failed to create vertex buffer", result)
	}

	vertex_buffer.vertices = vertices

	// Memory allocation and copying is done in memory/memory.odin

	log.log("Vulkan vertex buffer created")

	return vertex_buffer
}

destroy_vertex_buffer :: proc(
	vertex_buffer: ^VertexBuffer,
	device: vk.Device,
) {
	vk.DestroyBuffer(device, vertex_buffer.buffer, nil)
	vk.FreeMemory(device, vertex_buffer.memory, nil)

	log.log("Vulkan vertex buffer destroyed")
}
