package render_pass

import "../swapchain"
import "core:fmt"
import vk "vendor:vulkan"

RenderPass :: struct {
	render_pass: vk.RenderPass,
}

create_render_pass :: proc(
	swap_chain: swapchain.SwapChain,
	device: vk.Device,
) -> RenderPass {
	render_pass := RenderPass{}

	color_attachment := create_color_attachment(swap_chain)
	color_attachment_ref := create_color_attachment_ref(0)
	sub_pass := create_subpass(&color_attachment_ref)

	render_pass_info := vk.RenderPassCreateInfo{}
	render_pass_info.sType = vk.StructureType.RENDER_PASS_CREATE_INFO
	render_pass_info.attachmentCount = 1
	render_pass_info.pAttachments = &color_attachment
	render_pass_info.subpassCount = 1
	render_pass_info.pSubpasses = &sub_pass

	if vk.CreateRenderPass(
		   device,
		   &render_pass_info,
		   nil,
		   &render_pass.render_pass,
	   ) !=
	   vk.Result.SUCCESS {
		fmt.println("Failed to create Vulkan render pass")
	}

	fmt.println("Vulkan render pass created")

	return render_pass
}

destroy_render_pass :: proc(device: vk.Device, render_pass: RenderPass) {
	vk.DestroyRenderPass(device, render_pass.render_pass, nil)

	fmt.println("Vulkan render pass destroyed")
}

@(private)
create_color_attachment :: proc(
	swap_chain: swapchain.SwapChain,
) -> vk.AttachmentDescription {
	color_attachment := vk.AttachmentDescription{}
	color_attachment.format = swap_chain.format.format
	color_attachment.samples = vk.SampleCountFlags{._1}
	color_attachment.loadOp = vk.AttachmentLoadOp.CLEAR
	color_attachment.storeOp = vk.AttachmentStoreOp.STORE
	color_attachment.stencilLoadOp = vk.AttachmentLoadOp.DONT_CARE
	color_attachment.stencilStoreOp = vk.AttachmentStoreOp.DONT_CARE
	color_attachment.initialLayout = vk.ImageLayout.UNDEFINED
	color_attachment.finalLayout = vk.ImageLayout.PRESENT_SRC_KHR

	return color_attachment
}

@(private)
create_color_attachment_ref :: proc(
	attachment: u32,
) -> vk.AttachmentReference {
	color_attachment_ref := vk.AttachmentReference{}
	color_attachment_ref.attachment = attachment
	color_attachment_ref.layout = vk.ImageLayout.COLOR_ATTACHMENT_OPTIMAL

	return color_attachment_ref
}

@(private)
create_subpass :: proc(
	color_attachment_ref: ^vk.AttachmentReference,
) -> vk.SubpassDescription {
	subpass := vk.SubpassDescription{}
	subpass.pipelineBindPoint = vk.PipelineBindPoint.GRAPHICS
	subpass.colorAttachmentCount = 1
	subpass.pColorAttachments = color_attachment_ref

	return subpass
}
