package renderer

import vk "vendor:vulkan"

RenderPass :: struct {
	render_pass: vk.RenderPass,
}

render_pass_create :: proc(
	swap_chain: SwapChain,
	device: vk.Device,
) -> RenderPass {
	render_pass := RenderPass{}

	color_attachment := create_color_attachment(swap_chain)
	color_attachment_ref := create_color_attachment_ref(0)
	sub_pass := create_subpass(&color_attachment_ref)

	dependency := vk.SubpassDependency {
		srcSubpass    = vk.SUBPASS_EXTERNAL,
		dstSubpass    = 0,
		srcStageMask  = {.COLOR_ATTACHMENT_OUTPUT},
		srcAccessMask = {},
		dstStageMask  = {.COLOR_ATTACHMENT_OUTPUT},
		dstAccessMask = {.COLOR_ATTACHMENT_WRITE},
	}

	render_pass_info := vk.RenderPassCreateInfo {
		sType           = .RENDER_PASS_CREATE_INFO,
		attachmentCount = 1,
		pAttachments    = &color_attachment,
		subpassCount    = 1,
		pSubpasses      = &sub_pass,
		dependencyCount = 1,
		pDependencies   = &dependency,
	}

	if result := vk.CreateRenderPass(
		device,
		&render_pass_info,
		nil,
		&render_pass.render_pass,
	); result != .SUCCESS {
		log_fatal_with_vk_result("Failed to create Vulkan render pass", result)
	}

	log("Vulkan render pass created")

	return render_pass
}

render_pass_destroy :: proc(device: vk.Device, render_pass: RenderPass) {
	vk.DestroyRenderPass(device, render_pass.render_pass, nil)

	log("Vulkan render pass destroyed")
}

@(private = "file")
create_color_attachment :: proc(
	swap_chain: SwapChain,
) -> vk.AttachmentDescription {
	return vk.AttachmentDescription {
		format = swap_chain.format.format,
		samples = {._1},
		loadOp = .CLEAR,
		storeOp = .STORE,
		stencilLoadOp = .DONT_CARE,
		stencilStoreOp = .DONT_CARE,
		initialLayout = .UNDEFINED,
		finalLayout = .PRESENT_SRC_KHR,
	}
}

@(private = "file")
create_color_attachment_ref :: proc(
	attachment: u32,
) -> vk.AttachmentReference {
	return vk.AttachmentReference {
		attachment = attachment,
		layout = .COLOR_ATTACHMENT_OPTIMAL,
	}
}

@(private = "file")
create_subpass :: proc(
	color_attachment_ref: ^vk.AttachmentReference,
) -> vk.SubpassDescription {
	return vk.SubpassDescription {
		pipelineBindPoint = .GRAPHICS,
		colorAttachmentCount = 1,
		pColorAttachments = color_attachment_ref,
	}
}
