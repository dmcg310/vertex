package framebuffer

import "../log"
import "../render_pass"
import "../swapchain"
import vk "vendor:vulkan"

Framebuffer :: struct {
	id:          uint,
	framebuffer: vk.Framebuffer,
	width:       u32,
	height:      u32,
}

FramebufferManager :: struct {
	framebuffers: [dynamic]Framebuffer,
	swap_chain:   swapchain.SwapChain,
	_render_pass: render_pass.RenderPass,
}

create_framebuffer_manager :: proc(
	swap_chain: swapchain.SwapChain,
	_render_pass: render_pass.RenderPass,
) -> FramebufferManager {
	framebuffer_manager := FramebufferManager {
		framebuffers = make(
			[dynamic]Framebuffer,
			0,
			len(swap_chain.image_views),
		),
		swap_chain   = swap_chain,
		_render_pass = _render_pass,
	}

	log.log("Framebuffer manager created")

	return framebuffer_manager
}

destroy_framebuffer_manager :: proc(manager: ^FramebufferManager) {
	for framebuffer in manager.framebuffers {
		vk.DestroyFramebuffer(
			manager.swap_chain.device,
			framebuffer.framebuffer,
			nil,
		)
	}

	delete(manager.framebuffers)

	log.log("Framebuffer manager destroyed")
}

push_framebuffer :: proc(
	manager: ^FramebufferManager,
	attachment: ^vk.ImageView,
) {
	framebuffer := Framebuffer {
		id     = uint(len(manager.framebuffers)),
		width  = manager.swap_chain.extent_2d.width,
		height = manager.swap_chain.extent_2d.height,
	}

	framebuffer_info := vk.FramebufferCreateInfo {
		sType           = .FRAMEBUFFER_CREATE_INFO,
		renderPass      = manager._render_pass.render_pass,
		attachmentCount = 1,
		pAttachments    = attachment,
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
		log.log_fatal_with_vk_result("Failed to create framebuffer", result)
	}

	append(&manager.framebuffers, framebuffer)
}
