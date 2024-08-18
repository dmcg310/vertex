package vertexbuffer

import "core:math/linalg"
import vk "vendor:vulkan"

Vertex :: struct {
	pos:                    linalg.Vector2f32,
	color:                  linalg.Vector3f32,
	binding_description:    vk.VertexInputBindingDescription,
	attribute_descriptions: [2]vk.VertexInputAttributeDescription,
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
