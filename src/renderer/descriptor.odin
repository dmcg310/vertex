package renderer

import vk "vendor:vulkan"

DescriptorSetlayout :: struct {
	layout: vk.DescriptorSetLayout,
}

descriptor_set_layout_create :: proc(
	device: vk.Device,
) -> DescriptorSetlayout {
	descriptor_set_layout := DescriptorSetlayout{}

	ubo_layout_binding := vk.DescriptorSetLayoutBinding {
		binding            = 0,
		descriptorType     = .UNIFORM_BUFFER,
		descriptorCount    = 1,
		stageFlags         = {.VERTEX},
		pImmutableSamplers = nil,
	}

	layout_info := vk.DescriptorSetLayoutCreateInfo {
		sType        = .DESCRIPTOR_SET_LAYOUT_CREATE_INFO,
		bindingCount = 1,
		pBindings    = &ubo_layout_binding,
	}

	if result := vk.CreateDescriptorSetLayout(
		device,
		&layout_info,
		nil,
		&descriptor_set_layout.layout,
	); result != .SUCCESS {
		log_fatal_with_vk_result(
			"Failed to create descriptor set layout",
			result,
		)
	}

	log("Vulkan descriptor set layout created")

	return descriptor_set_layout
}

descriptor_set_layout_destroy :: proc(
	device: vk.Device,
	descriptor_set_layout: DescriptorSetlayout,
) {
	vk.DestroyDescriptorSetLayout(device, descriptor_set_layout.layout, nil)

	log("Vulkan descriptor set layout destroyed")
}
