package renderer

import vk "vendor:vulkan"

Framebuffer :: struct {
	id:          uint,
	framebuffer: vk.Framebuffer,
	width:       u32,
	height:      u32,
}

FramebufferManager :: struct {
	framebuffers: [dynamic]Framebuffer,
	swap_chain:   SwapChain,
	render_pass:  vk.RenderPass,
}

framebuffer_manager_create :: proc(
	swap_chain: SwapChain,
	render_pass: vk.RenderPass,
	depth_image_view: DepthImageView,
) -> FramebufferManager {
	framebuffer_manager := FramebufferManager {
		framebuffers = make(
			[dynamic]Framebuffer,
			0,
			len(swap_chain.image_views),
		),
		swap_chain   = swap_chain,
		render_pass  = render_pass,
	}

	for &image_view in framebuffer_manager.swap_chain.image_views {
		framebuffer_push(&framebuffer_manager, &image_view, depth_image_view)
	}

	log("Framebuffer manager created")

	return framebuffer_manager
}

framebuffer_manager_destroy :: proc(manager: ^FramebufferManager) {
	for framebuffer in manager.framebuffers {
		vk.DestroyFramebuffer(
			manager.swap_chain.device,
			framebuffer.framebuffer,
			nil,
		)
	}

	delete(manager.framebuffers)

	log("Framebuffer manager destroyed")
}

framebuffer_push :: proc(
	manager: ^FramebufferManager,
	attachment: ^vk.ImageView,
	depth_image_view: DepthImageView,
) {
	framebuffer := Framebuffer {
		id     = uint(len(manager.framebuffers)),
		width  = manager.swap_chain.extent_2d.width,
		height = manager.swap_chain.extent_2d.height,
	}

	attachments: []vk.ImageView = {attachment^, depth_image_view.view}

	framebuffer_info := vk.FramebufferCreateInfo {
		sType           = .FRAMEBUFFER_CREATE_INFO,
		renderPass      = manager.render_pass,
		attachmentCount = u32(len(attachments)),
		pAttachments    = raw_data(attachments),
		width           = framebuffer.width,
		height          = framebuffer.height,
		layers          = 1,
	}

	if result := vk.CreateFramebuffer(
		manager.swap_chain.device,
		&framebuffer_info,
		nil,
		&framebuffer.framebuffer,
	); result != .SUCCESS {
		log_fatal_with_vk_result("Failed to create framebuffer", result)
	}

	append(&manager.framebuffers, framebuffer)
}
