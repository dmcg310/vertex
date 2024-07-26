package pipeline

import "../shader"
import vk "vendor:vulkan"

VERT_PATH :: "shaders/vertex.spv"
FRAG_PATH :: "shaders/fragment.spv"

GraphicsPipeline :: struct {
	pipeline: vk.Pipeline,
}

create_graphics_pipeline :: proc(device: vk.Device) -> GraphicsPipeline {
	pipeline := GraphicsPipeline{}

	shaders, ok := shader.read_shaders({VERT_PATH, FRAG_PATH})
	if !ok {
		return pipeline
	}

	vert_shader_module := shader.create_shader_module(
		shaders.vertex_shader,
		device,
	)
	frag_shader_module := shader.create_shader_module(
		shaders.fragment_shader,
		device,
	)

	shader_stages := [2]vk.PipelineShaderStageCreateInfo {
		shader.create_shader_stage({.VERTEX}, vert_shader_module),
		shader.create_shader_stage({.FRAGMENT}, frag_shader_module),
	}

	vk.DestroyShaderModule(device, vert_shader_module, nil)
	vk.DestroyShaderModule(device, frag_shader_module, nil)

	return pipeline
}
