package device

import "../instance"
import "../util"
import "../window"
import "core:fmt"
import "core:math"
import "vendor:glfw"
import vk "vendor:vulkan"

Surface :: struct {
	surface: vk.SurfaceKHR,
}

Device :: struct {
	physical_device: vk.PhysicalDevice,
	logical_device:  vk.Device,
	graphics_queue:  vk.Queue,
	properties:      vk.PhysicalDeviceProperties,
	surface:         Surface,
	present_queue:   vk.Queue,
}

QueueFamily :: enum {
	Graphics,
	Present,
}

QueueFamilyIndices :: struct {
	data: [QueueFamily]int,
}

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

DEVICE_EXTENSIONS := [dynamic]string{"VK_KHR_swapchain"}

create_device :: proc() -> Device {
	return Device{}
}

pick_physical_device :: proc(
	device: ^Device,
	instance: vk.Instance,
	surface: vk.SurfaceKHR,
) {
	device.physical_device = nil

	device_count: u32 = 0
	vk.EnumeratePhysicalDevices(instance, &device_count, nil)

	if device_count == 0 {
		panic("Failed to find GPUs with Vulkan support")
	}

	devices := make([]vk.PhysicalDevice, device_count)
	vk.EnumeratePhysicalDevices(instance, &device_count, raw_data(devices))

	highest_score := 0
	for _device in devices {
		score := is_device_suitable(_device, surface)
		if score > highest_score {
			device.physical_device = _device
			highest_score = score
		}
	}

	if highest_score == 0 || device.physical_device == nil {
		panic("Failed to find a suitable GPU")
	}
}

create_logical_device :: proc(
	device: ^Device,
	_instance: instance.Instance,
	surface: Surface,
) {
	indices := find_queue_families(device.physical_device, surface.surface)

	unique_indices: map[int]b8
	for i in indices.data do unique_indices[i] = true

	queue_priority: f32 = 1.0

	queue_create_infos := [dynamic]vk.DeviceQueueCreateInfo{}

	for k, _ in unique_indices {
		queue_create_info := vk.DeviceQueueCreateInfo{}

		queue_create_info.sType = vk.StructureType.DEVICE_QUEUE_CREATE_INFO
		queue_create_info.queueFamilyIndex = u32(indices.data[.Graphics])
		queue_create_info.queueCount = 1
		queue_create_info.pQueuePriorities = &queue_priority

		append(&queue_create_infos, queue_create_info)
	}

	device_features := vk.PhysicalDeviceFeatures{}

	create_info := vk.DeviceCreateInfo{}
	create_info.sType = vk.StructureType.DEVICE_CREATE_INFO
	create_info.enabledExtensionCount = u32(len(DEVICE_EXTENSIONS))
	create_info.ppEnabledExtensionNames = raw_data(
		util.dynamic_array_of_strings_to_cstrings(DEVICE_EXTENSIONS),
	)
	create_info.pQueueCreateInfos = raw_data(queue_create_infos)
	create_info.queueCreateInfoCount = u32(len(queue_create_infos))
	create_info.pEnabledFeatures = &device_features
	create_info.enabledLayerCount = 0

	if _instance.validation_layers_enabled {
		create_info.enabledLayerCount = u32(len(instance.VALIDATION_LAYERS))
		create_info.ppEnabledLayerNames = raw_data(
			util.dynamic_array_of_strings_to_cstrings(
				instance.VALIDATION_LAYERS,
			),
		)
	} else {
		create_info.enabledLayerCount = 0
	}

	if result := vk.CreateDevice(
		device.physical_device,
		&create_info,
		nil,
		&device.logical_device,
	); result != vk.Result.SUCCESS {
		panic("Failed to create logical device")
	}

	vk.GetDeviceQueue(
		device.logical_device,
		u32(indices.data[.Graphics]),
		0,
		&device.graphics_queue,
	)

	vk.load_proc_addresses(device.logical_device)

	fmt.println("Vulkan logical device created")

	vk.GetPhysicalDeviceProperties(device.physical_device, &device.properties)
	display_device_properties(device.properties)
}

create_surface :: proc(
	_instance: instance.Instance,
	_window: ^window.Window,
) -> Surface {
	surface := Surface{}
	surface.surface = window.create_surface(_instance.instance, _window)

	return surface
}

create_swap_chain :: proc(
	device: Device,
	surface: Surface,
	window: ^window.Window,
) -> SwapChain {
	swap_chain := SwapChain{}

	swap_chain_support := query_swap_chain_support(
		device.physical_device,
		surface.surface,
	)
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
	create_info.surface = surface.surface
	create_info.minImageCount = image_count
	create_info.imageFormat = surface_format.format
	create_info.imageColorSpace = surface_format.colorSpace
	create_info.imageExtent = extent_2d
	create_info.imageArrayLayers = 1
	create_info.imageUsage = vk.ImageUsageFlags{.COLOR_ATTACHMENT}

	indices := find_queue_families(device.physical_device, surface.surface)
	queue_family_indices := []u32 {
		u32(indices.data[.Graphics]),
		u32(indices.data[.Present]),
	}

	if indices.data[.Graphics] != indices.data[.Present] {
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
		device.logical_device,
		&create_info,
		nil,
		&swap_chain.swap_chain,
	); result != vk.Result.SUCCESS {
		panic("Failed to create swap chain")
	}

	swap_chain.format = surface_format
	swap_chain.extent_2d = extent_2d

	vk.GetSwapchainImagesKHR(
		device.logical_device,
		swap_chain.swap_chain,
		&image_count,
		nil,
	)

	swap_chain.images = make([]vk.Image, image_count)
	vk.GetSwapchainImagesKHR(
		device.logical_device,
		swap_chain.swap_chain,
		&image_count,
		raw_data(swap_chain.images),
	)

	swap_chain.image_views = []vk.ImageView{}
	swap_chain.framebuffers = []vk.Framebuffer{}

	fmt.println("Vulkan swap chain created")

	return swap_chain
}

destroy_swap_chain :: proc(device: Device, swap_chain: SwapChain) {
	vk.DestroySwapchainKHR(device.logical_device, swap_chain.swap_chain, nil)

	fmt.println("Vulkan swap chain destroyed")
}

destroy_surface :: proc(
	surface: Surface,
	instance: instance.Instance,
	_window: ^window.Window,
) {
	window.destroy_surface(surface.surface, instance.instance, _window)
}

destroy_logical_device :: proc(device: Device) {
	if device.logical_device != nil {
		vk.DestroyDevice(device.logical_device, nil)
	}

	fmt.println("Vulkan logical device destroyed")
}

@(private)
is_device_suitable :: proc(
	device: vk.PhysicalDevice,
	surface: vk.SurfaceKHR,
) -> int {
	device_properties := vk.PhysicalDeviceProperties{}
	device_features := vk.PhysicalDeviceFeatures{}

	vk.GetPhysicalDeviceProperties(device, &device_properties)
	vk.GetPhysicalDeviceFeatures(device, &device_features)

	score := 0
	if device_properties.deviceType == vk.PhysicalDeviceType.DISCRETE_GPU {
		score += 1000
	}

	score += int(device_properties.limits.maxImageDimension2D)

	if !device_features.geometryShader {
		return 0
	}

	if !check_device_extension_support(device) {
		return 0
	}

	swap_chain_adequate := false
	if check_device_extension_support(device) {
		swap_chain_support := query_swap_chain_support(device, surface)
		swap_chain_adequate =
			len(swap_chain_support.formats) > 0 &&
			len(swap_chain_support.present_modes) > 0
	}

	if !swap_chain_adequate {
		return 0
	}

	return score
}

@(private)
find_queue_families :: proc(
	device: vk.PhysicalDevice,
	surface: vk.SurfaceKHR,
) -> QueueFamilyIndices {
	indices := QueueFamilyIndices{}

	queue_family_count: u32 = 0
	vk.GetPhysicalDeviceQueueFamilyProperties(device, &queue_family_count, nil)

	queue_families := make([]vk.QueueFamilyProperties, queue_family_count)
	vk.GetPhysicalDeviceQueueFamilyProperties(
		device,
		&queue_family_count,
		raw_data(queue_families),
	)

	for queue_family, i in queue_families {
		if .GRAPHICS in queue_family.queueFlags &&
		   indices.data[.Graphics] == -1 {
			indices.data[.Graphics] = i
		}

		present_support: b32
		vk.GetPhysicalDeviceSurfaceSupportKHR(
			device,
			u32(i),
			surface,
			&present_support,
		)
		if present_support && indices.data[.Present] == -1 {
			indices.data[.Present] = i
		}
	}

	return indices
}

@(private)
check_device_extension_support :: proc(device: vk.PhysicalDevice) -> bool {
	ext_count: u32
	vk.EnumerateDeviceExtensionProperties(device, nil, &ext_count, nil)

	available_extensions := make([]vk.ExtensionProperties, ext_count)
	vk.EnumerateDeviceExtensionProperties(
		device,
		nil,
		&ext_count,
		raw_data(available_extensions),
	)

	for ext in DEVICE_EXTENSIONS {
		found: b32

		for available_ext in &available_extensions {
			temp := available_ext.extensionName

			if util.string_from_bytes(temp[:]) == ext {
				found = true
				break
			}
		}

		if !found {
			return false
		}
	}

	return true
}

@(private)
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
		details.present_modes = make([]vk.PresentModeKHR, format_count)

		vk.GetPhysicalDeviceSurfacePresentModesKHR(
			physical_device,
			surface,
			&format_count,
			raw_data(details.present_modes),
		)
	}

	present_count: u32 = 0
	vk.GetPhysicalDeviceSurfacePresentModesKHR(
		physical_device,
		surface,
		&present_count,
		nil,
	)

	if present_count != 0 {
		details.formats = make([]vk.SurfaceFormatKHR, present_count)

		vk.GetPhysicalDeviceSurfaceFormatsKHR(
			physical_device,
			surface,
			&present_count,
			raw_data(details.formats),
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

@(private)
display_device_properties :: proc(properties: vk.PhysicalDeviceProperties) {
	fmt.printf("GPU Name: %s -> ", properties.deviceName)
	fmt.printf("Driver Version: %d -> ", properties.driverVersion)
	fmt.printf("Vendor ID: %d -> ", properties.vendorID)
	fmt.printf("Device ID: %d -> ", properties.deviceID)
	fmt.printf(
		"Device Type: %s\n",
		device_type_to_string(properties.deviceType),
	)
}

@(private)
device_type_to_string :: proc(deviceType: vk.PhysicalDeviceType) -> string {
	switch deviceType {
	case vk.PhysicalDeviceType.INTEGRATED_GPU:
		return "Integrated GPU"
	case vk.PhysicalDeviceType.DISCRETE_GPU:
		return "Discrete GPU"
	case vk.PhysicalDeviceType.VIRTUAL_GPU:
		return "Virtual GPU"
	case vk.PhysicalDeviceType.CPU:
		return "CPU"
	case vk.PhysicalDeviceType.OTHER:
		return "Other"
	}

	return "Unknown"
}
