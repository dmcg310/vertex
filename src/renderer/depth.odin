package renderer

import vk "vendor:vulkan"

DepthImage :: struct {
	image: VMAImage,
}

DepthImageView :: struct {
	view: vk.ImageView,
}

depth_resources_create :: proc(
	device: Device,
	swap_chain: SwapChain,
	vma_allocator: VMAAllocator,
) -> (
	DepthImage,
	DepthImageView,
) {
	depth_image := DepthImage{}
	depth_image_view := DepthImageView{}

	depth_format := depth_find_format(device.physical_device)

	depth_image.image = vma_image_create(
		vma_allocator,
		swap_chain.extent_2d.width,
		swap_chain.extent_2d.height,
		depth_format,
		.OPTIMAL,
		{.DEPTH_STENCIL_ATTACHMENT},
		.AUTO,
	)

	depth_image_view.view = image_view_create(
		device.logical_device,
		depth_image.image.image,
		depth_format,
		{.DEPTH},
	)

	log("Vulkan depth resources created")

	return depth_image, depth_image_view
}

depth_resources_destroy :: proc(
	vma_allocator: VMAAllocator,
	device: vk.Device,
	depth_image: DepthImage,
	depth_image_view: DepthImageView,
) {
	vma_image_destroy(vma_allocator, depth_image.image)
	vk.DestroyImageView(device, depth_image_view.view, nil)

	log("Vulkan depth resources destroyed")
}

depth_find_format :: proc(physical_device: vk.PhysicalDevice) -> vk.Format {
	return find_supported_format(
		{.D32_SFLOAT, .D32_SFLOAT_S8_UINT, .D24_UNORM_S8_UINT},
		.OPTIMAL,
		{.DEPTH_STENCIL_ATTACHMENT},
		physical_device,
	)
}

@(private = "file")
find_supported_format :: proc(
	candidates: []vk.Format,
	tiling: vk.ImageTiling,
	features: vk.FormatFeatureFlags,
	physical_device: vk.PhysicalDevice,
) -> vk.Format {
	for format in candidates {
		properties: vk.FormatProperties
		vk.GetPhysicalDeviceFormatProperties(
			physical_device,
			format,
			&properties,
		)

		if tiling == .LINEAR &&
		   (properties.linearTilingFeatures & features) == features {
			return format
		} else if tiling == .OPTIMAL &&
		   (properties.optimalTilingFeatures & features) == features {
			return format
		}
	}

	log_fatal("Failed to find supported depth format")

	return {}
}

@(private = "file")
has_stencil_component :: proc(format: vk.Format) -> bool {
	return format == .D32_SFLOAT_S8_UINT || format == .D24_UNORM_S8_UINT
}
