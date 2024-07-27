package pipeline

import "../render_pass"
import "../shader"
import "../swapchain"
import "core:fmt"
import vk "vendor:vulkan"

VERT_PATH :: "shaders/vert.spv"
FRAG_PATH :: "shaders/frag.spv"

DYNAMIC_STATES := []vk.DynamicState {
	vk.DynamicState.VIEWPORT,
	vk.DynamicState.SCISSOR,
}

GraphicsPipeline :: struct {
	pipeline:        vk.Pipeline,
	pipeline_layout: vk.PipelineLayout,
	render_pass:     render_pass.RenderPass,
}

create_graphics_pipeline :: proc(
	swap_chain: swapchain.SwapChain,
	device: vk.Device,
) -> GraphicsPipeline {
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

	pipeline.render_pass = render_pass.create_render_pass(swap_chain, device)

	vk.DestroyShaderModule(device, vert_shader_module, nil)
	vk.DestroyShaderModule(device, frag_shader_module, nil)

	fmt.println("Vulkan graphics pipeline created")

	return pipeline
}

destroy_pipeline :: proc(device: vk.Device, pipeline: GraphicsPipeline) {
	render_pass.destroy_render_pass(device, pipeline.render_pass)
	vk.DestroyPipeline(device, pipeline.pipeline, nil)
	vk.DestroyPipelineLayout(device, pipeline.pipeline_layout, nil)

	fmt.println("Vulkan graphics pipeline destroyed")
}

@(private)
create_pipeline_layout :: proc(device: vk.Device) -> vk.PipelineLayout {
	layout_info := vk.PipelineLayoutCreateInfo{}
	layout_info.sType = vk.StructureType.PIPELINE_LAYOUT_CREATE_INFO

	pipeline_layout := vk.PipelineLayout{}
	if vk.CreatePipelineLayout(device, &layout_info, nil, &pipeline_layout) !=
	   vk.Result.SUCCESS {
		panic("Failed to create pipeline layout")
	}

	return pipeline_layout
}

@(private)
create_dynamic_state :: proc() -> vk.PipelineDynamicStateCreateInfo {
	dynamic_state := vk.PipelineDynamicStateCreateInfo{}
	dynamic_state.sType = vk.StructureType.PIPELINE_DYNAMIC_STATE_CREATE_INFO
	dynamic_state.dynamicStateCount = u32(len(DYNAMIC_STATES))
	dynamic_state.pDynamicStates = raw_data(DYNAMIC_STATES)

	return dynamic_state
}

@(private)
create_viewport_state :: proc() -> vk.PipelineViewportStateCreateInfo {
	viewport_state := vk.PipelineViewportStateCreateInfo{}
	viewport_state.sType = vk.StructureType.PIPELINE_VIEWPORT_STATE_CREATE_INFO
	viewport_state.viewportCount = 1
	viewport_state.scissorCount = 1
	return viewport_state
}

@(private)
create_vertex_input :: proc() -> vk.PipelineVertexInputStateCreateInfo {
	vertex_input := vk.PipelineVertexInputStateCreateInfo{}
	vertex_input.sType =
		vk.StructureType.PIPELINE_VERTEX_INPUT_STATE_CREATE_INFO
	vertex_input.vertexBindingDescriptionCount = 0
	vertex_input.vertexAttributeDescriptionCount = 0

	return vertex_input
}

@(private)
create_input_assembly :: proc(
	topology: vk.PrimitiveTopology,
	restart: b32,
) -> vk.PipelineInputAssemblyStateCreateInfo {
	input_assembly := vk.PipelineInputAssemblyStateCreateInfo{}
	input_assembly.sType =
		vk.StructureType.PIPELINE_INPUT_ASSEMBLY_STATE_CREATE_INFO
	input_assembly.topology = topology
	input_assembly.primitiveRestartEnable = b32(
		restart ? u32(vk.TRUE) : u32(vk.FALSE),
	)
	return input_assembly
}

@(private)
create_viewport :: proc(
	width: f32,
	height: f32,
	swap_chain: swapchain.SwapChain,
) -> vk.Viewport {
	viewport := vk.Viewport{}
	viewport.x = 0.0
	viewport.y = 0.0
	viewport.width = f32(swap_chain.extent_2d.width)
	viewport.height = f32(swap_chain.extent_2d.height)
	viewport.minDepth = 0.0
	viewport.maxDepth = 1.0

	return viewport
}

@(private)
create_rasterizer :: proc(
	polygon_mode: vk.PolygonMode,
	line_width: f32,
	cull_mode: vk.CullModeFlags,
	front_face: vk.FrontFace,
	enable_detph_bias: b32,
) -> vk.PipelineRasterizationStateCreateInfo {
	rasterizer := vk.PipelineRasterizationStateCreateInfo{}
	rasterizer.sType =
		vk.StructureType.PIPELINE_RASTERIZATION_STATE_CREATE_INFO
	rasterizer.depthClampEnable = false
	rasterizer.rasterizerDiscardEnable = false
	rasterizer.polygonMode = polygon_mode
	rasterizer.lineWidth = line_width
	rasterizer.cullMode = cull_mode
	rasterizer.frontFace = front_face
	rasterizer.depthBiasEnable = b32(
		enable_detph_bias ? u32(vk.TRUE) : u32(vk.FALSE),
	)

	return rasterizer
}

@(private)
create_multisampling :: proc() -> vk.PipelineMultisampleStateCreateInfo {
	multisampling := vk.PipelineMultisampleStateCreateInfo{}
	multisampling.sType =
		vk.StructureType.PIPELINE_MULTISAMPLE_STATE_CREATE_INFO
	multisampling.sampleShadingEnable = false
	multisampling.rasterizationSamples = vk.SampleCountFlags{._1}

	return multisampling
}

@(private)
create_color_blend_attachment :: proc(
	enable_blend: b32,
) -> vk.PipelineColorBlendAttachmentState {
	color_blend := vk.PipelineColorBlendAttachmentState{}
	color_blend.colorWriteMask = vk.ColorComponentFlags{.R | .G | .B | .A}

	if enable_blend {
		color_blend.blendEnable = true
		color_blend.srcColorBlendFactor = vk.BlendFactor.SRC_ALPHA
		color_blend.dstColorBlendFactor = vk.BlendFactor.ONE_MINUS_SRC_ALPHA
		color_blend.colorBlendOp = vk.BlendOp.ADD
		color_blend.srcAlphaBlendFactor = vk.BlendFactor.ONE
		color_blend.dstAlphaBlendFactor = vk.BlendFactor.ZERO
		color_blend.alphaBlendOp = vk.BlendOp.ADD
	} else {
		color_blend.blendEnable = false
	}

	return color_blend
}

@(private)
create_color_blend_state :: proc(
	color_blend_attachment: ^vk.PipelineColorBlendAttachmentState,
) -> vk.PipelineColorBlendStateCreateInfo {
	color_blend_state := vk.PipelineColorBlendStateCreateInfo{}
	color_blend_state.sType =
		vk.StructureType.PIPELINE_COLOR_BLEND_STATE_CREATE_INFO
	color_blend_state.logicOpEnable = false
	color_blend_state.attachmentCount = 1
	color_blend_state.pAttachments = color_blend_attachment

	return color_blend_state
}
