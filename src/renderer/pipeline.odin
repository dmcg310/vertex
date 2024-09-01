package renderer

import vk "vendor:vulkan"

VERT_PATH :: "assets/shaders/vert.spv"
FRAG_PATH :: "assets/shaders/frag.spv"

DYNAMIC_STATES := []vk.DynamicState{.VIEWPORT, .SCISSOR}

GraphicsPipeline :: struct {
	pipeline:        vk.Pipeline,
	pipeline_layout: vk.PipelineLayout,
	render_pass:     vk.RenderPass,
}

pipeline_create :: proc(
	swap_chain: SwapChain,
	device: Device,
	descriptor_set_layout: ^DescriptorSetlayout,
) -> GraphicsPipeline {
	if VERT_PATH == "" || FRAG_PATH == "" {
		return {}
	}

	pipeline := GraphicsPipeline{}

	shaders, ok := shaders_read({VERT_PATH, FRAG_PATH})
	if !ok {
		return pipeline
	}

	vert_shader_module := shader_module_create(
		shaders.vertex_shader,
		device.logical_device,
	)
	frag_shader_module := shader_module_create(
		shaders.fragment_shader,
		device.logical_device,
	)

	shader_stages := []vk.PipelineShaderStageCreateInfo {
		shader_stage_create({.VERTEX}, vert_shader_module),
		shader_stage_create({.FRAGMENT}, frag_shader_module),
	}

	vertex_input := create_vertex_input()
	input_assembly := create_input_assembly(.TRIANGLE_LIST, false)
	viewport_state := create_viewport_state()
	rasterizer := create_rasterizer(
		.FILL,
		1.0,
		{.BACK},
		.COUNTER_CLOCKWISE,
		false,
	)
	multisampling := create_multisampling()
	depth_stencil := create_depth_stencil()
	color_blend_attachment := create_color_blend_attachment(true)
	color_blending := create_color_blend_state(&color_blend_attachment)
	dynamic_state := create_dynamic_state()
	pipeline.pipeline_layout = create_pipeline_layout(
		device.logical_device,
		descriptor_set_layout,
	)
	pipeline.render_pass = create_render_pass(swap_chain, device)

	pipeline_info := vk.GraphicsPipelineCreateInfo {
		sType               = .GRAPHICS_PIPELINE_CREATE_INFO,
		stageCount          = u32(len(shader_stages)),
		pStages             = raw_data(shader_stages),
		pVertexInputState   = &vertex_input,
		pInputAssemblyState = &input_assembly,
		pViewportState      = &viewport_state,
		pRasterizationState = &rasterizer,
		pMultisampleState   = &multisampling,
		pDepthStencilState  = &depth_stencil,
		pColorBlendState    = &color_blending,
		pDynamicState       = &dynamic_state,
		layout              = pipeline.pipeline_layout,
		renderPass          = pipeline.render_pass,
		subpass             = 0,
	}

	if result := vk.CreateGraphicsPipelines(
		device.logical_device,
		0,
		1,
		&pipeline_info,
		nil,
		&pipeline.pipeline,
	); result != .SUCCESS {
		log_fatal_with_vk_result("Failed to create graphics pipeline", result)
	}

	vk.DestroyShaderModule(device.logical_device, vert_shader_module, nil)
	vk.DestroyShaderModule(device.logical_device, frag_shader_module, nil)

	log("Vulkan graphics pipeline created")

	return pipeline
}

pipeline_destroy :: proc(device: vk.Device, pipeline: GraphicsPipeline) {
	vk.DestroyRenderPass(device, pipeline.render_pass, nil)

	vk.DestroyPipeline(device, pipeline.pipeline, nil)
	vk.DestroyPipelineLayout(device, pipeline.pipeline_layout, nil)

	log("Vulkan graphics pipeline destroyed")
}

@(private = "file")
create_viewport_state :: proc() -> vk.PipelineViewportStateCreateInfo {
	return vk.PipelineViewportStateCreateInfo {
		sType = .PIPELINE_VIEWPORT_STATE_CREATE_INFO,
		viewportCount = 1,
		scissorCount = 1,
	}
}

@(private = "file")
create_vertex_input :: proc() -> vk.PipelineVertexInputStateCreateInfo {
	binding_description := new(
		vk.VertexInputBindingDescription,
		context.temp_allocator,
	)
	attribute_descriptions := new(
		[3]vk.VertexInputAttributeDescription,
		context.temp_allocator,
	)

	binding_description^ = buffer_get_vertex_binding_description()
	attribute_descriptions^ = buffer_get_vertex_attribute_descriptions()

	res := vk.PipelineVertexInputStateCreateInfo {
		sType                           = .PIPELINE_VERTEX_INPUT_STATE_CREATE_INFO,
		vertexBindingDescriptionCount   = 1,
		vertexAttributeDescriptionCount = u32(len(attribute_descriptions)),
		pVertexBindingDescriptions      = binding_description,
		pVertexAttributeDescriptions    = raw_data(attribute_descriptions[:]),
	}

	return res
}

@(private = "file")
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

@(private = "file")
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

@(private = "file")
create_multisampling :: proc() -> vk.PipelineMultisampleStateCreateInfo {
	return vk.PipelineMultisampleStateCreateInfo {
		sType = .PIPELINE_MULTISAMPLE_STATE_CREATE_INFO,
		sampleShadingEnable = false,
		rasterizationSamples = {._1},
	}
}

@(private = "file")
create_depth_stencil :: proc() -> vk.PipelineDepthStencilStateCreateInfo {
	return vk.PipelineDepthStencilStateCreateInfo {
		sType = .PIPELINE_DEPTH_STENCIL_STATE_CREATE_INFO,
		depthTestEnable = true,
		depthWriteEnable = true,
		depthCompareOp = .LESS,
		depthBoundsTestEnable = false,
		minDepthBounds = 0.0,
		maxDepthBounds = 1.0,
		stencilTestEnable = false,
		front = {},
		back = {},
	}
}

@(private = "file")
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

@(private = "file")
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

@(private = "file")
create_dynamic_state :: proc() -> vk.PipelineDynamicStateCreateInfo {
	return vk.PipelineDynamicStateCreateInfo {
		sType = .PIPELINE_DYNAMIC_STATE_CREATE_INFO,
		dynamicStateCount = 2,
		pDynamicStates = &DYNAMIC_STATES[0],
	}
}

@(private = "file")
create_pipeline_layout :: proc(
	device: vk.Device,
	descriptor_set_layout: ^DescriptorSetlayout,
) -> vk.PipelineLayout {
	layout_info := vk.PipelineLayoutCreateInfo {
		sType          = .PIPELINE_LAYOUT_CREATE_INFO,
		setLayoutCount = 1,
		pSetLayouts    = &descriptor_set_layout.layout,
	}

	pipeline_layout := vk.PipelineLayout{}
	if result := vk.CreatePipelineLayout(
		device,
		&layout_info,
		nil,
		&pipeline_layout,
	); result != .SUCCESS {
		log_fatal_with_vk_result("Failed to create pipeline layout", result)
	}

	return pipeline_layout
}

@(private = "file")
create_render_pass :: proc(
	swap_chain: SwapChain,
	device: Device,
) -> vk.RenderPass {
	render_pass := vk.RenderPass{}

	color_attachment := vk.AttachmentDescription {
		format         = swap_chain.format.format,
		samples        = {._1},
		loadOp         = .CLEAR,
		storeOp        = .STORE,
		stencilLoadOp  = .DONT_CARE,
		stencilStoreOp = .DONT_CARE,
		initialLayout  = .UNDEFINED,
		finalLayout    = .PRESENT_SRC_KHR,
	}

	depth_attachment := vk.AttachmentDescription {
		format         = depth_find_format(device.physical_device),
		samples        = {._1},
		loadOp         = .CLEAR,
		storeOp        = .DONT_CARE,
		stencilLoadOp  = .DONT_CARE,
		stencilStoreOp = .DONT_CARE,
		initialLayout  = .UNDEFINED,
		finalLayout    = .DEPTH_STENCIL_ATTACHMENT_OPTIMAL,
	}

	color_attachment_ref := vk.AttachmentReference {
		attachment = 0,
		layout     = .COLOR_ATTACHMENT_OPTIMAL,
	}

	depth_attachment_ref := vk.AttachmentReference {
		attachment = 1,
		layout     = .DEPTH_STENCIL_ATTACHMENT_OPTIMAL,
	}

	sub_pass := vk.SubpassDescription {
		pipelineBindPoint       = .GRAPHICS,
		colorAttachmentCount    = 1,
		pColorAttachments       = &color_attachment_ref,
		pDepthStencilAttachment = &depth_attachment_ref,
	}

	dependency := vk.SubpassDependency {
		srcSubpass    = vk.SUBPASS_EXTERNAL,
		dstSubpass    = 0,
		srcStageMask  = {.COLOR_ATTACHMENT_OUTPUT, .EARLY_FRAGMENT_TESTS},
		srcAccessMask = {},
		dstStageMask  = {.COLOR_ATTACHMENT_OUTPUT, .EARLY_FRAGMENT_TESTS},
		dstAccessMask = {
			.COLOR_ATTACHMENT_WRITE,
			.DEPTH_STENCIL_ATTACHMENT_WRITE,
		},
	}

	attachments: []vk.AttachmentDescription = {
		color_attachment,
		depth_attachment,
	}

	render_pass_info := vk.RenderPassCreateInfo {
		sType           = .RENDER_PASS_CREATE_INFO,
		attachmentCount = u32(len(attachments)),
		pAttachments    = raw_data(attachments),
		subpassCount    = 1,
		pSubpasses      = &sub_pass,
		dependencyCount = 1,
		pDependencies   = &dependency,
	}

	if result := vk.CreateRenderPass(
		device.logical_device,
		&render_pass_info,
		nil,
		&render_pass,
	); result != .SUCCESS {
		log_fatal_with_vk_result("Failed to create Vulkan render pass", result)
	}

	return render_pass
}
