package pipeline

import "../render_pass"
import "../shader"
import "../swapchain"
import "core:fmt"
import vk "vendor:vulkan"

VERT_PATH :: "shaders/vert.spv"
FRAG_PATH :: "shaders/frag.spv"

DYNAMIC_STATES := []vk.DynamicState{.VIEWPORT, .SCISSOR}

GraphicsPipeline :: struct {
	pipeline:        vk.Pipeline,
	pipeline_layout: vk.PipelineLayout,
	_render_pass:    render_pass.RenderPass,
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

	shader_stages := []vk.PipelineShaderStageCreateInfo {
		shader.create_shader_stage(
			vk.ShaderStageFlags{.VERTEX},
			vert_shader_module,
		),
		shader.create_shader_stage(
			vk.ShaderStageFlags{.FRAGMENT},
			frag_shader_module,
		),
	}

	pipeline._render_pass = render_pass.create_render_pass(swap_chain, device)

	pipeline.pipeline_layout = create_pipeline_layout(device)

	vertex_input := create_vertex_input()
	input_assembly := create_input_assembly(
		vk.PrimitiveTopology.TRIANGLE_LIST,
		false,
	)

	viewport := create_viewport(
		f32(swap_chain.extent_2d.width),
		f32(swap_chain.extent_2d.height),
		swap_chain,
	)
	viewport_state := create_viewport_state()

	rasterizer := create_rasterizer(
		vk.PolygonMode.FILL,
		1.0,
		vk.CullModeFlags{.BACK},
		vk.FrontFace.COUNTER_CLOCKWISE,
		false,
	)

	multisampling := create_multisampling()
	color_blend_attachment := create_color_blend_attachment(true)
	color_blending := create_color_blend_state(&color_blend_attachment)
	dynamic_state := create_dynamic_state()

	pipeline_info := create_pipeline_info(
		shader_stages,
		&vertex_input,
		&input_assembly,
		&viewport_state,
		&rasterizer,
		&multisampling,
		&color_blending,
		&dynamic_state,
		pipeline,
	)

	if vk.CreateGraphicsPipelines(
		   device,
		   0,
		   1,
		   &pipeline_info,
		   nil,
		   &pipeline.pipeline,
	   ) !=
	   .SUCCESS {
		panic("Failed to create graphics pipeline")
	}

	vk.DestroyShaderModule(device, vert_shader_module, nil)
	vk.DestroyShaderModule(device, frag_shader_module, nil)

	fmt.println("Vulkan graphics pipeline created")

	return pipeline
}

destroy_pipeline :: proc(device: vk.Device, pipeline: GraphicsPipeline) {
	render_pass.destroy_render_pass(device, pipeline._render_pass)
	vk.DestroyPipeline(device, pipeline.pipeline, nil)
	vk.DestroyPipelineLayout(device, pipeline.pipeline_layout, nil)

	fmt.println("Vulkan graphics pipeline destroyed")
}

@(private)
create_pipeline_info :: proc(
	shader_stages: []vk.PipelineShaderStageCreateInfo,
	vertex_input: ^vk.PipelineVertexInputStateCreateInfo,
	input_assembly: ^vk.PipelineInputAssemblyStateCreateInfo,
	viewport_state: ^vk.PipelineViewportStateCreateInfo,
	rasterizer: ^vk.PipelineRasterizationStateCreateInfo,
	multisampling: ^vk.PipelineMultisampleStateCreateInfo,
	color_blending: ^vk.PipelineColorBlendStateCreateInfo,
	dynamic_state: ^vk.PipelineDynamicStateCreateInfo,
	pipeline: GraphicsPipeline,
) -> vk.GraphicsPipelineCreateInfo {
	pipeline_info := vk.GraphicsPipelineCreateInfo{}
	pipeline_info.sType = .GRAPHICS_PIPELINE_CREATE_INFO
	pipeline_info.stageCount = u32(len(shader_stages))
	pipeline_info.pStages = raw_data(shader_stages)
	pipeline_info.pVertexInputState = vertex_input
	pipeline_info.pInputAssemblyState = input_assembly
	pipeline_info.pViewportState = viewport_state
	pipeline_info.pRasterizationState = rasterizer
	pipeline_info.pMultisampleState = multisampling
	pipeline_info.pColorBlendState = color_blending
	pipeline_info.pDynamicState = dynamic_state
	pipeline_info.layout = pipeline.pipeline_layout
	pipeline_info.renderPass = pipeline._render_pass.render_pass
	pipeline_info.subpass = 0

	return pipeline_info
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
	dynamic_state := vk.PipelineDynamicStateCreateInfo {
		sType             = .PIPELINE_DYNAMIC_STATE_CREATE_INFO,
		dynamicStateCount = 2,
		pDynamicStates    = &DYNAMIC_STATES[0],
	}

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
