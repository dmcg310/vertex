package renderer

import "core:math"

import "vendor:glfw"
import vk "vendor:vulkan"

SwapChainSupportDetails :: struct {
	capabilities:  vk.SurfaceCapabilitiesKHR,
	formats:       []vk.SurfaceFormatKHR,
	present_modes: []vk.PresentModeKHR,
}

SwapChain :: struct {
	swap_chain:           vk.SwapchainKHR,
	format:               vk.SurfaceFormatKHR,
	extent_2d:            vk.Extent2D,
	images:               []vk.Image,
	image_views:          []vk.ImageView,
	device:               vk.Device,
	queue_family_indices: QueueFamilyIndices,
}

swap_chain_create :: proc(
	device: Device,
	surface: Surface,
	window: ^Window,
) -> SwapChain {
	swap_chain := SwapChain{}

	swap_chain_support := swap_chain_query_support(
		device.physical_device,
		surface.surface,
	)
	defer swap_chain_support_details_destroy(swap_chain_support)

	surface_format := choose_swap_surface_format(swap_chain_support.formats)
	present_mode := choose_swap_present_mode(swap_chain_support.present_modes)
	extent_2d := choose_swap_extent(swap_chain_support.capabilities, window)

	image_count := swap_chain_support.capabilities.minImageCount + 1

	if swap_chain_support.capabilities.maxImageCount > 0 &&
	   image_count > swap_chain_support.capabilities.maxImageCount {
		image_count = swap_chain_support.capabilities.maxImageCount
	}

	create_info := vk.SwapchainCreateInfoKHR {
		sType            = .SWAPCHAIN_CREATE_INFO_KHR,
		surface          = surface.surface,
		minImageCount    = image_count,
		imageFormat      = surface_format.format,
		imageColorSpace  = surface_format.colorSpace,
		imageExtent      = extent_2d,
		imageArrayLayers = 1,
		imageUsage       = {.COLOR_ATTACHMENT},
	}

	indices := device_find_queue_families(
		device.physical_device,
		surface.surface,
	)
	queue_family_indices := []u32 {
		u32(indices.data[QueueFamily.Graphics]),
		u32(indices.data[QueueFamily.Present]),
	}

	swap_chain.queue_family_indices = indices

	if indices.data[QueueFamily.Graphics] !=
	   indices.data[QueueFamily.Present] {
		create_info.imageSharingMode = .CONCURRENT
		create_info.queueFamilyIndexCount = 2
		create_info.pQueueFamilyIndices = raw_data(queue_family_indices)
	} else {
		create_info.imageSharingMode = .EXCLUSIVE
		create_info.queueFamilyIndexCount = 0
		create_info.pQueueFamilyIndices = nil
	}

	create_info.preTransform = swap_chain_support.capabilities.currentTransform
	create_info.compositeAlpha = {.OPAQUE}
	create_info.presentMode = present_mode
	create_info.clipped = true
	create_info.oldSwapchain = vk.SwapchainKHR(0)

	if result := vk.CreateSwapchainKHR(
		device.logical_device,
		&create_info,
		nil,
		&swap_chain.swap_chain,
	); result != .SUCCESS {
		log_fatal_with_vk_result("Failed to create swap chain", result)
	}

	swap_chain.format = surface_format
	swap_chain.extent_2d = extent_2d

	vk.GetSwapchainImagesKHR(
		device.logical_device,
		swap_chain.swap_chain,
		&image_count,
		nil,
	)

	swap_chain.images = make([]vk.Image, image_count, context.temp_allocator)
	vk.GetSwapchainImagesKHR(
		device.logical_device,
		swap_chain.swap_chain,
		&image_count,
		raw_data(swap_chain.images),
	)

	swap_chain.image_views = []vk.ImageView{}
	swap_chain.device = device.logical_device

	log("Vulkan swap chain created")

	create_image_views(&swap_chain, device.logical_device)

	return swap_chain
}

swap_chain_destroy :: proc(device: vk.Device, swap_chain: SwapChain) {
	vk.DestroySwapchainKHR(device, swap_chain.swap_chain, nil)

	for image_view in swap_chain.image_views {
		vk.DestroyImageView(device, image_view, nil)
	}

	log("Vulkan swap chain destroyed")
}

swap_chain_support_details_destroy :: proc(
	swap_chain_support: SwapChainSupportDetails,
) {
	delete(swap_chain_support.present_modes)
	delete(swap_chain_support.formats)
}

swap_chain_query_support :: proc(
	physical_device: vk.PhysicalDevice,
	surface: vk.SurfaceKHR,
) -> SwapChainSupportDetails {
	details := SwapChainSupportDetails{}

	vk.GetPhysicalDeviceSurfaceCapabilitiesKHR(
		physical_device,
		surface,
		&details.capabilities,
	)

	format_count: u32 = 0
	vk.GetPhysicalDeviceSurfaceFormatsKHR(
		physical_device,
		surface,
		&format_count,
		nil,
	)

	if format_count != 0 {
		details.formats = make([]vk.SurfaceFormatKHR, format_count)
		vk.GetPhysicalDeviceSurfaceFormatsKHR(
			physical_device,
			surface,
			&format_count,
			raw_data(details.formats),
		)
	}

	present_mode_count: u32 = 0
	vk.GetPhysicalDeviceSurfacePresentModesKHR(
		physical_device,
		surface,
		&present_mode_count,
		nil,
	)

	if present_mode_count != 0 {
		details.present_modes = make([]vk.PresentModeKHR, present_mode_count)
		vk.GetPhysicalDeviceSurfacePresentModesKHR(
			physical_device,
			surface,
			&present_mode_count,
			raw_data(details.present_modes),
		)
	}

	return details
}

swap_chain_get_next_image :: proc(
	device: vk.Device,
	swap_chain: SwapChain,
	semaphore: vk.Semaphore,
) -> (
	u32,
	bool,
) {
	image_index: u32
	result := vk.AcquireNextImageKHR(
		device,
		swap_chain.swap_chain,
		~u64(0),
		semaphore,
		0,
		&image_index,
	)

	if result == .ERROR_OUT_OF_DATE_KHR {
		return image_index, false
	} else if result != .SUCCESS && result != .SUBOPTIMAL_KHR {
		log_fatal("Failed to acquire swap chain image")
	}

	return image_index, true
}

swap_chain_present :: proc(
	queue: vk.Queue,
	swap_chain: ^SwapChain,
	image_index: ^u32,
	wait_semaphore: ^vk.Semaphore,
) -> bool {
	present_info := vk.PresentInfoKHR {
		sType              = .PRESENT_INFO_KHR,
		waitSemaphoreCount = 1,
		pWaitSemaphores    = wait_semaphore,
		swapchainCount     = 1,
		pSwapchains        = &swap_chain.swap_chain,
		pImageIndices      = image_index,
	}

	if result := vk.QueuePresentKHR(queue, &present_info); result != .SUCCESS {
		return false
	}

	return true
}

swap_chain_recreate :: proc(renderer: ^Renderer) {
	log("Recreating swap chain due to framebuffer resize")

	width, height: i32 = 0, 0
	for width == 0 || height == 0 {
		width, height = window_get_framebuffer_size(renderer.resources.window)
		window_wait_events()
	}

	device_wait_idle(renderer.resources.device.logical_device)

	swap_chain_cleanup(
		&renderer.resources.framebuffer_manager,
		renderer.resources.device.logical_device,
		renderer.resources.swap_chain,
		renderer.resources.pipeline,
		renderer.resources.vma_allocator,
		renderer.resources.depth_image,
		renderer.resources.depth_image_view,
	)

	renderer.resources.swap_chain = swap_chain_create(
		renderer.resources.device,
		renderer.resources.surface,
		&renderer.resources.window,
	)

	renderer.resources.pipeline = pipeline_create(
		renderer.resources.swap_chain,
		renderer.resources.device,
		&renderer.resources.descriptor_set_layout,
	)

	renderer.resources.depth_image, renderer.resources.depth_image_view =
		depth_resources_create(
			renderer.resources.device,
			renderer.resources.swap_chain,
			renderer.resources.vma_allocator,
		)

	renderer.resources.framebuffer_manager = framebuffer_manager_create(
		renderer.resources.swap_chain,
		renderer.resources.pipeline.render_pass,
		renderer.resources.depth_image_view,
	)

	renderer.resources.command_buffers = command_buffers_create(
		renderer.resources.device.logical_device,
		renderer.resources.command_pool,
	)

	is_framebuffer_resized = false
}

@(private = "file")
create_image_views :: proc(swap_chain: ^SwapChain, device: vk.Device) {
	swap_chain.image_views = make(
		[]vk.ImageView,
		len(swap_chain.images),
		context.temp_allocator,
	)

	for _, i in swap_chain.images {
		swap_chain.image_views[i] = image_view_create(
			device,
			swap_chain.images[i],
			swap_chain.format.format,
			{.COLOR},
		)
	}
}

@(private = "file")
choose_swap_surface_format :: proc(
	available_formats: []vk.SurfaceFormatKHR,
) -> vk.SurfaceFormatKHR {
	for available_format in available_formats {
		if available_format.format == .B8G8R8A8_SRGB &&
		   available_format.colorSpace == .SRGB_NONLINEAR {
			return available_format
		}
	}

	return available_formats[0]
}

@(private = "file")
choose_swap_present_mode :: proc(
	available_present_modes: []vk.PresentModeKHR,
) -> vk.PresentModeKHR {
	for available_present_mode in available_present_modes {
		if available_present_mode == .MAILBOX {
			return available_present_mode
		}
	}

	return .FIFO
}

@(private = "file")
choose_swap_extent :: proc(
	capabilities: vk.SurfaceCapabilitiesKHR,
	window: ^Window,
) -> vk.Extent2D {
	if capabilities.currentExtent.width != 0xFFFFFFFF {
		return capabilities.currentExtent
	}

	width, height := glfw.GetFramebufferSize(window.handle)

	actual_extent := vk.Extent2D {
		width  = u32(width),
		height = u32(height),
	}

	actual_extent.width = math.clamp(
		actual_extent.width,
		capabilities.minImageExtent.width,
		capabilities.maxImageExtent.width,
	)

	actual_extent.height = math.clamp(
		actual_extent.height,
		capabilities.minImageExtent.height,
		capabilities.maxImageExtent.height,
	)

	return actual_extent
}

@(private = "file")
swap_chain_cleanup :: proc(
	framebuffer_manager: ^FramebufferManager,
	logical_device: vk.Device,
	swap_chain: SwapChain,
	pipeline: GraphicsPipeline,
	vma_allocator: VMAAllocator,
	depth_image: DepthImage,
	depth_image_view: DepthImageView,
) {
	framebuffer_manager_destroy(framebuffer_manager)
	depth_resources_destroy(
		vma_allocator,
		logical_device,
		depth_image,
		depth_image_view,
	)
	swap_chain_destroy(logical_device, swap_chain)
	pipeline_destroy(logical_device, pipeline)
}
