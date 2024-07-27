package framebuffer

import "../render_pass"
import "../swapchain"
import "core:fmt"
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
	framebuffer_manager := FramebufferManager{}
	framebuffer_manager.framebuffers = make(
		[dynamic]Framebuffer,
		0,
		len(swap_chain.image_views),
	)
	framebuffer_manager.swap_chain = swap_chain
	framebuffer_manager._render_pass = _render_pass

	fmt.println("Framebuffer manager created")

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

	fmt.println("Framebuffer manager destroyed")
}

push_framebuffer :: proc(
	manager: ^FramebufferManager,
	attachment: ^vk.ImageView,
) {
	framebuffer := Framebuffer{}
	framebuffer.id = uint(len(manager.framebuffers))
	framebuffer.width = manager.swap_chain.extent_2d.width
	framebuffer.height = manager.swap_chain.extent_2d.height

	framebuffer_info := vk.FramebufferCreateInfo{}
	framebuffer_info.sType = vk.StructureType.FRAMEBUFFER_CREATE_INFO
	framebuffer_info.renderPass = manager._render_pass.render_pass
	framebuffer_info.attachmentCount = 1
	framebuffer_info.pAttachments = attachment
	framebuffer_info.width = framebuffer.width
	framebuffer_info.height = framebuffer.height
	framebuffer_info.layers = 1

	if vk.CreateFramebuffer(
		   manager.swap_chain.device,
		   &framebuffer_info,
		   nil,
		   &framebuffer.framebuffer,
	   ) !=
	   vk.Result.SUCCESS {
		panic("failed to create framebuffer!")
	}

	append(&manager.framebuffers, framebuffer)
}
