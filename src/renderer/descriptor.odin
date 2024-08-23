package renderer

import vk "vendor:vulkan"

DescriptorSetlayout :: struct {
	layout: vk.DescriptorSetLayout,
}

DescriptorPool :: struct {
	pool: vk.DescriptorPool,
}

DescriptorSets :: []vk.DescriptorSet

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

descriptor_pool_create :: proc(device: vk.Device) -> DescriptorPool {
	descriptor_pool := DescriptorPool{}

	pool_size := vk.DescriptorPoolSize {
		type            = .UNIFORM_BUFFER,
		descriptorCount = u32(MAX_FRAMES_IN_FLIGHT),
	}

	pool_info := vk.DescriptorPoolCreateInfo {
		sType         = .DESCRIPTOR_POOL_CREATE_INFO,
		poolSizeCount = 1,
		pPoolSizes    = &pool_size,
		maxSets       = u32(MAX_FRAMES_IN_FLIGHT),
	}

	if result := vk.CreateDescriptorPool(
		device,
		&pool_info,
		nil,
		&descriptor_pool.pool,
	); result != .SUCCESS {
		log_fatal_with_vk_result("Failed to create descriptor pool", result)
	}

	log("Vulkan descriptor pool created")

	return descriptor_pool
}

descriptor_pool_destroy :: proc(
	device: vk.Device,
	descriptor_pool: DescriptorPool,
) {
	vk.DestroyDescriptorPool(device, descriptor_pool.pool, nil)

	log("Vulkan descriptor pool destroyed")
}

descriptor_sets_create :: proc(
	descriptor_pool: DescriptorPool,
	device: vk.Device,
	uniform_buffers: UniformBuffers,
	descriptor_set_layout: DescriptorSetlayout,
) -> DescriptorSets {
	layouts := make(
		[]vk.DescriptorSetLayout,
		MAX_FRAMES_IN_FLIGHT,
		context.temp_allocator,
	)

	for i in 0 ..< MAX_FRAMES_IN_FLIGHT {
		layouts[i] = descriptor_set_layout.layout
	}

	allocate_info := vk.DescriptorSetAllocateInfo {
		sType              = .DESCRIPTOR_SET_ALLOCATE_INFO,
		descriptorPool     = descriptor_pool.pool,
		descriptorSetCount = u32(MAX_FRAMES_IN_FLIGHT),
		pSetLayouts        = raw_data(layouts),
	}

	descriptor_sets := make(
		[]vk.DescriptorSet,
		MAX_FRAMES_IN_FLIGHT,
		context.temp_allocator,
	)

	if result := vk.AllocateDescriptorSets(
		device,
		&allocate_info,
		raw_data(descriptor_sets),
	); result != .SUCCESS {
		log_fatal_with_vk_result("Failed to allocate descriptor sets", result)
	}

	for i in 0 ..< MAX_FRAMES_IN_FLIGHT {
		buffer_info := vk.DescriptorBufferInfo {
			buffer = uniform_buffers.buffers[i].buffer,
			offset = 0,
			range  = size_of(UniformBufferObject),
		}

		descriptor_write := vk.WriteDescriptorSet {
			sType            = .WRITE_DESCRIPTOR_SET,
			dstSet           = descriptor_sets[i],
			dstBinding       = 0,
			dstArrayElement  = 0,
			descriptorType   = .UNIFORM_BUFFER,
			descriptorCount  = 1,
			pBufferInfo      = &buffer_info,
			pImageInfo       = nil,
			pTexelBufferView = nil,
		}

		vk.UpdateDescriptorSets(device, 1, &descriptor_write, 0, nil)
	}

	log("Vulkan descriptor sets created")

	return descriptor_sets
}
