package swapchain

import "../shared"
import "../util"
import "../window"
import "core:fmt"
import "core:math"
import "vendor:glfw"
import vk "vendor:vulkan"

SwapChainSupportDetails :: struct {
	capabilities:  vk.SurfaceCapabilitiesKHR,
	formats:       []vk.SurfaceFormatKHR,
	present_modes: []vk.PresentModeKHR,
}

SwapChain :: struct {
	swap_chain:   vk.SwapchainKHR,
	format:       vk.SurfaceFormatKHR,
	extent_2d:    vk.Extent2D,
	images:       []vk.Image,
	image_views:  []vk.ImageView,
	framebuffers: []vk.Framebuffer,
}

create_swap_chain :: proc(
	device: vk.Device,
	physical_device: vk.PhysicalDevice,
	surface: vk.SurfaceKHR,
	window: ^window.Window,
) -> SwapChain {
	swap_chain := SwapChain{}

	swap_chain_support := query_swap_chain_support(physical_device, surface)
	surface_format := choose_swap_surface_format(swap_chain_support.formats)
	present_mode := choose_swap_present_mode(swap_chain_support.present_modes)
	extent_2d := choose_swap_extent(swap_chain_support.capabilities, window)

	image_count := swap_chain_support.capabilities.minImageCount + 1

	if swap_chain_support.capabilities.maxImageCount > 0 &&
	   image_count > swap_chain_support.capabilities.maxImageCount {
		image_count = swap_chain_support.capabilities.maxImageCount
	}

	create_info := vk.SwapchainCreateInfoKHR{}
	create_info.sType = vk.StructureType.SWAPCHAIN_CREATE_INFO_KHR
	create_info.surface = surface
	create_info.minImageCount = image_count
	create_info.imageFormat = surface_format.format
	create_info.imageColorSpace = surface_format.colorSpace
	create_info.imageExtent = extent_2d
	create_info.imageArrayLayers = 1
	create_info.imageUsage = vk.ImageUsageFlags{.COLOR_ATTACHMENT}

	indices := shared.find_queue_families(physical_device, surface).data
	queue_family_indices := []u32 {
		u32(indices[shared.QueueFamily.Graphics]),
		u32(indices[shared.QueueFamily.Present]),
	}

	if indices[shared.QueueFamily.Graphics] !=
	   indices[shared.QueueFamily.Present] {
		create_info.imageSharingMode = vk.SharingMode.CONCURRENT
		create_info.queueFamilyIndexCount = 2
		create_info.pQueueFamilyIndices = raw_data(queue_family_indices)
	} else {
		create_info.imageSharingMode = vk.SharingMode.EXCLUSIVE
		create_info.queueFamilyIndexCount = 0
		create_info.pQueueFamilyIndices = nil
	}

	create_info.preTransform = swap_chain_support.capabilities.currentTransform
	create_info.compositeAlpha = vk.CompositeAlphaFlagsKHR{.OPAQUE}
	create_info.presentMode = present_mode
	create_info.clipped = true
	create_info.oldSwapchain = vk.SwapchainKHR(0)

	if result := vk.CreateSwapchainKHR(
		device,
		&create_info,
		nil,
		&swap_chain.swap_chain,
	); result != vk.Result.SUCCESS {
		panic("Failed to create swap chain")
	}

	swap_chain.format = surface_format
	swap_chain.extent_2d = extent_2d

	vk.GetSwapchainImagesKHR(device, swap_chain.swap_chain, &image_count, nil)

	swap_chain.images = make([]vk.Image, image_count)
	vk.GetSwapchainImagesKHR(
		device,
		swap_chain.swap_chain,
		&image_count,
		raw_data(swap_chain.images),
	)

	swap_chain.image_views = []vk.ImageView{}
	swap_chain.framebuffers = []vk.Framebuffer{}

	fmt.println("Vulkan swap chain created")

	return swap_chain
}

destroy_swap_chain :: proc(device: vk.Device, swap_chain: SwapChain) {
	vk.DestroySwapchainKHR(device, swap_chain.swap_chain, nil)

	fmt.println("Vulkan swap chain destroyed")
}

query_swap_chain_support :: proc(
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

@(private)
choose_swap_surface_format :: proc(
	available_formats: []vk.SurfaceFormatKHR,
) -> vk.SurfaceFormatKHR {
	for available_format in available_formats {
		if available_format.format == vk.Format.B8G8R8A8_SRGB &&
		   available_format.colorSpace == vk.ColorSpaceKHR.SRGB_NONLINEAR {
			return available_format
		}
	}

	return available_formats[0]
}

@(private)
choose_swap_present_mode :: proc(
	available_present_modes: []vk.PresentModeKHR,
) -> vk.PresentModeKHR {
	for available_present_mode in available_present_modes {
		if available_present_mode == vk.PresentModeKHR.MAILBOX {
			return available_present_mode
		}
	}

	return vk.PresentModeKHR.FIFO
}

@(private)
choose_swap_extent :: proc(
	capabilities: vk.SurfaceCapabilitiesKHR,
	_window: ^window.Window,
) -> vk.Extent2D {
	if capabilities.currentExtent.width != 0xFFFFFFFF {
		return capabilities.currentExtent
	}

	width, height := glfw.GetFramebufferSize(_window.handle)

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
