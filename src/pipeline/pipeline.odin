package pipeline

import "../log"
import "../render_pass"
import "../shader"
import "../swapchain"
import "../vertexbuffer"
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
		shader.create_shader_stage({.VERTEX}, vert_shader_module),
		shader.create_shader_stage({.FRAGMENT}, frag_shader_module),
	}

	pipeline._render_pass = render_pass.create_render_pass(swap_chain, device)

	pipeline.pipeline_layout = create_pipeline_layout(device)

	vertex_input := create_vertex_input()
	input_assembly := create_input_assembly(.TRIANGLE_LIST, false)

	viewport_state := create_viewport_state()

	rasterizer := create_rasterizer(.FILL, 1.0, {}, .COUNTER_CLOCKWISE, false)

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

	if result := vk.CreateGraphicsPipelines(
		device,
		0,
		1,
		&pipeline_info,
		nil,
		&pipeline.pipeline,
	); result != .SUCCESS {
		log.log_fatal_with_vk_result(
			"Failed to create graphics pipeline",
			result,
		)
	}

	vk.DestroyShaderModule(device, vert_shader_module, nil)
	vk.DestroyShaderModule(device, frag_shader_module, nil)

	log.log("Vulkan graphics pipeline created")

	return pipeline
}

destroy_pipeline :: proc(device: vk.Device, pipeline: GraphicsPipeline) {
	render_pass.destroy_render_pass(device, pipeline._render_pass)

	vk.DestroyPipeline(device, pipeline.pipeline, nil)
	vk.DestroyPipelineLayout(device, pipeline.pipeline_layout, nil)

	log.log("Vulkan graphics pipeline destroyed")
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
	return vk.GraphicsPipelineCreateInfo {
		sType = .GRAPHICS_PIPELINE_CREATE_INFO,
		stageCount = u32(len(shader_stages)),
		pStages = raw_data(shader_stages),
		pVertexInputState = vertex_input,
		pInputAssemblyState = input_assembly,
		pViewportState = viewport_state,
		pRasterizationState = rasterizer,
		pMultisampleState = multisampling,
		pColorBlendState = color_blending,
		pDynamicState = dynamic_state,
		layout = pipeline.pipeline_layout,
		renderPass = pipeline._render_pass.render_pass,
		subpass = 0,
	}
}

@(private)
create_pipeline_layout :: proc(device: vk.Device) -> vk.PipelineLayout {
	layout_info := vk.PipelineLayoutCreateInfo {
		sType = .PIPELINE_LAYOUT_CREATE_INFO,
	}

	pipeline_layout := vk.PipelineLayout{}
	if result := vk.CreatePipelineLayout(
		device,
		&layout_info,
		nil,
		&pipeline_layout,
	); result != .SUCCESS {
		log.log_fatal_with_vk_result(
			"Failed to create pipeline layout",
			result,
		)
	}

	return pipeline_layout
}

@(private)
create_dynamic_state :: proc() -> vk.PipelineDynamicStateCreateInfo {
	return vk.PipelineDynamicStateCreateInfo {
		sType = .PIPELINE_DYNAMIC_STATE_CREATE_INFO,
		dynamicStateCount = 2,
		pDynamicStates = &DYNAMIC_STATES[0],
	}
}

@(private)
create_viewport_state :: proc() -> vk.PipelineViewportStateCreateInfo {
	return vk.PipelineViewportStateCreateInfo {
		sType = .PIPELINE_VIEWPORT_STATE_CREATE_INFO,
		viewportCount = 1,
		scissorCount = 1,
	}
}

@(private)
create_vertex_input :: proc() -> vk.PipelineVertexInputStateCreateInfo {
	binding_description := new(
		vk.VertexInputBindingDescription,
		context.temp_allocator,
	)
	attribute_descriptions := new(
		[2]vk.VertexInputAttributeDescription,
		context.temp_allocator,
	)

	binding_description^ = vertexbuffer.get_binding_description()
	attribute_descriptions^ = vertexbuffer.get_attribute_descriptions()

	res := vk.PipelineVertexInputStateCreateInfo {
		sType                           = .PIPELINE_VERTEX_INPUT_STATE_CREATE_INFO,
		vertexBindingDescriptionCount   = 1,
		vertexAttributeDescriptionCount = u32(len(attribute_descriptions)),
		pVertexBindingDescriptions      = binding_description,
		pVertexAttributeDescriptions    = raw_data(attribute_descriptions[:]),
	}

	return res
}

@(private)
create_input_assembly :: proc(
	topology: vk.PrimitiveTopology,
	restart: b32,
) -> vk.PipelineInputAssemblyStateCreateInfo {
	return vk.PipelineInputAssemblyStateCreateInfo {
		sType = .PIPELINE_INPUT_ASSEMBLY_STATE_CREATE_INFO,
		topology = topology,
		primitiveRestartEnable = b32(restart ? u32(vk.TRUE) : u32(vk.FALSE)),
	}
}

@(private)
create_rasterizer :: proc(
	polygon_mode: vk.PolygonMode,
	line_width: f32,
	cull_mode: vk.CullModeFlags,
	front_face: vk.FrontFace,
	enable_detph_bias: b32,
) -> vk.PipelineRasterizationStateCreateInfo {
	return vk.PipelineRasterizationStateCreateInfo {
		sType = .PIPELINE_RASTERIZATION_STATE_CREATE_INFO,
		depthClampEnable = false,
		rasterizerDiscardEnable = false,
		polygonMode = polygon_mode,
		lineWidth = line_width,
		cullMode = cull_mode,
		frontFace = front_face,
		depthBiasEnable = b32(
			enable_detph_bias ? u32(vk.TRUE) : u32(vk.FALSE),
		),
	}
}

@(private)
create_multisampling :: proc() -> vk.PipelineMultisampleStateCreateInfo {
	return vk.PipelineMultisampleStateCreateInfo {
		sType = .PIPELINE_MULTISAMPLE_STATE_CREATE_INFO,
		sampleShadingEnable = false,
		rasterizationSamples = {._1},
	}
}

@(private)
create_color_blend_attachment :: proc(
	enable_blend: b32,
) -> vk.PipelineColorBlendAttachmentState {
	color_blend := vk.PipelineColorBlendAttachmentState {
		colorWriteMask = {.R, .G, .B, .A},
	}

	if enable_blend {
		color_blend.blendEnable = true
		color_blend.srcColorBlendFactor = .SRC_ALPHA
		color_blend.dstColorBlendFactor = .ONE_MINUS_SRC_ALPHA
		color_blend.colorBlendOp = .ADD
		color_blend.srcAlphaBlendFactor = .ONE
		color_blend.dstAlphaBlendFactor = .ZERO
		color_blend.alphaBlendOp = .ADD
	} else {
		color_blend.blendEnable = false
	}

	return color_blend
}

@(private)
create_color_blend_state :: proc(
	color_blend_attachment: ^vk.PipelineColorBlendAttachmentState,
) -> vk.PipelineColorBlendStateCreateInfo {
	return vk.PipelineColorBlendStateCreateInfo {
		sType = .PIPELINE_COLOR_BLEND_STATE_CREATE_INFO,
		logicOpEnable = false,
		attachmentCount = 1,
		pAttachments = color_blend_attachment,
	}
}
