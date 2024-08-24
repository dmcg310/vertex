package renderer

import "core:fmt"
import "core:strings"

import vk "vendor:vulkan"

import "../util"

Surface :: struct {
	surface: vk.SurfaceKHR,
}

Device :: struct {
	physical_device:       vk.PhysicalDevice,
	logical_device:        vk.Device,
	graphics_queue:        vk.Queue,
	graphics_family_index: u32,
	properties:            vk.PhysicalDeviceProperties,
	surface:               Surface,
	present_queue:         vk.Queue,
}

QueueFamily :: enum {
	Graphics,
	Present,
}

QueueFamilyIndices :: struct {
	data: [QueueFamily]int,
}

DEVICE_EXTENSIONS := [dynamic]string{"VK_KHR_swapchain"}

MAX_FRAMES_IN_FLIGHT :: 2

device_create :: proc() -> Device {
	return Device{}
}

device_pick_physical :: proc(
	device: ^Device,
	instance: Instance,
	surface: Surface,
) {
	device.physical_device = nil

	device_count: u32 = 0
	vk.EnumeratePhysicalDevices(instance.instance, &device_count, nil)

	if device_count == 0 {
		log_fatal("Failed to find GPUs with Vulkan support")
	}

	devices := make([]vk.PhysicalDevice, device_count, context.temp_allocator)
	vk.EnumeratePhysicalDevices(
		instance.instance,
		&device_count,
		raw_data(devices),
	)

	highest_score := 0
	for _device in devices {
		score := device_is_suitable(_device, surface.surface)
		if score > highest_score {
			device.physical_device = _device
			highest_score = score
		}
	}

	if highest_score == 0 || device.physical_device == nil {
		log_fatal("Failed to find a suitable GPU")
	}
}

device_logical_create :: proc(
	device: ^Device,
	_instance: Instance,
	surface: Surface,
) {
	indices := device_find_queue_families(
		device.physical_device,
		surface.surface,
	)

	unique_indices := make(map[int]struct {})
	defer delete(unique_indices)

	unique_indices[indices.data[.Graphics]] = {}
	unique_indices[indices.data[.Present]] = {}

	device.graphics_family_index = u32(indices.data[.Graphics])

	queue_priority: f32 = 1.0

	queue_create_infos := make(
		[dynamic]vk.DeviceQueueCreateInfo,
		0,
		len(unique_indices),
		context.temp_allocator,
	)

	for queue_family_index in unique_indices {
		queue_create_info := vk.DeviceQueueCreateInfo {
			sType            = .DEVICE_QUEUE_CREATE_INFO,
			queueFamilyIndex = u32(queue_family_index),
			queueCount       = 1,
			pQueuePriorities = &queue_priority,
		}

		append(&queue_create_infos, queue_create_info)
	}

	device_features := vk.PhysicalDeviceFeatures {
		samplerAnisotropy = true,
	}

	cstring_arr_device_extensions := util.dynamic_array_of_strings_to_cstrings(
		DEVICE_EXTENSIONS,
	)

	create_info := vk.DeviceCreateInfo {
		sType                   = .DEVICE_CREATE_INFO,
		enabledExtensionCount   = u32(len(DEVICE_EXTENSIONS)),
		ppEnabledExtensionNames = raw_data(cstring_arr_device_extensions),
		pQueueCreateInfos       = raw_data(queue_create_infos),
		queueCreateInfoCount    = u32(len(queue_create_infos)),
		pEnabledFeatures        = &device_features,
		enabledLayerCount       = 0,
	}

	if _instance.validation_layers_enabled {
		create_info.enabledLayerCount = u32(len(VALIDATION_LAYERS))

		cstring_arr_validation_layers :=
			util.dynamic_array_of_strings_to_cstrings(VALIDATION_LAYERS)
		create_info.ppEnabledLayerNames = raw_data(
			cstring_arr_validation_layers,
		)
	}

	if result := vk.CreateDevice(
		device.physical_device,
		&create_info,
		nil,
		&device.logical_device,
	); result != .SUCCESS {
		log_fatal("Failed to create logical device")
	}

	vk.GetDeviceQueue(
		device.logical_device,
		u32(indices.data[.Graphics]),
		0,
		&device.graphics_queue,
	)

	vk.GetDeviceQueue(
		device.logical_device,
		u32(indices.data[.Present]),
		0,
		&device.present_queue,
	)

	vk.load_proc_addresses(device.logical_device)

	log("Vulkan logical device created")
}

device_surface_create :: proc(instance: Instance, window: ^Window) -> Surface {
	return Surface{surface = window_create_surface(instance.instance, window)}
}

device_surface_destroy :: proc(
	surface: Surface,
	instance: Instance,
	window: ^Window,
) {
	window_destroy_surface(surface.surface, instance.instance, window)
}

device_logical_destroy :: proc(device: vk.Device) {
	if device != nil {
		vk.DestroyDevice(device, nil)
	}

	log("Vulkan logical device destroyed")
}

device_print_properties :: proc(device: vk.PhysicalDevice) {
	properties := vk.PhysicalDeviceProperties{}
	vk.GetPhysicalDeviceProperties(device, &properties)

	temp := properties.deviceName
	device_name := strings.trim_right(
		strings.clone_from_bytes(temp[:], context.temp_allocator),
		"\x00",
	)

	properties_str := fmt.aprintf(
		"Using: %s. Device Type: %s",
		device_name,
		device_type_to_string(properties.deviceType),
	)
	defer delete(properties_str)

	log(properties_str)
}

device_find_queue_families :: proc(
	device: vk.PhysicalDevice,
	surface: vk.SurfaceKHR,
) -> QueueFamilyIndices {
	indices := QueueFamilyIndices{}

	queue_family_count: u32 = 0
	vk.GetPhysicalDeviceQueueFamilyProperties(device, &queue_family_count, nil)

	queue_families := make(
		[]vk.QueueFamilyProperties,
		queue_family_count,
		context.temp_allocator,
	)

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

device_wait_idle :: proc(device: vk.Device) {
	vk.DeviceWaitIdle(device)
}

@(private = "file")
device_is_suitable :: proc(
	device: vk.PhysicalDevice,
	surface: vk.SurfaceKHR,
) -> int {
	device_properties := vk.PhysicalDeviceProperties{}
	device_features := vk.PhysicalDeviceFeatures{}

	vk.GetPhysicalDeviceProperties(device, &device_properties)
	vk.GetPhysicalDeviceFeatures(device, &device_features)

	score := 0
	if device_properties.deviceType == .DISCRETE_GPU {
		score += 1000
	}

	score += int(device_properties.limits.maxImageDimension2D)

	if !device_features.geometryShader {
		return 0
	}

	if !device_features.samplerAnisotropy {
		return 0
	}

	if !device_check_extension_support(device) {
		return 0
	}

	swap_chain_adequate := false
	if device_check_extension_support(device) {
		swap_chain_support := swap_chain_query_support(device, surface)
		defer swap_chain_support_details_destroy(swap_chain_support)

		swap_chain_adequate =
			len(swap_chain_support.formats) > 0 &&
			len(swap_chain_support.present_modes) > 0
	}

	if !swap_chain_adequate {
		return 0
	}

	return score
}

@(private = "file")
device_check_extension_support :: proc(device: vk.PhysicalDevice) -> bool {
	ext_count: u32
	vk.EnumerateDeviceExtensionProperties(device, nil, &ext_count, nil)

	available_extensions := make(
		[]vk.ExtensionProperties,
		ext_count,
		context.temp_allocator,
	)
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
			comparison := util.string_from_bytes(temp[:])

			if comparison == ext {
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

@(private = "file")
device_type_to_string :: proc(deviceType: vk.PhysicalDeviceType) -> string {
	switch deviceType {
	case .INTEGRATED_GPU:
		return "Integrated GPU"
	case .DISCRETE_GPU:
		return "Discrete GPU"
	case .VIRTUAL_GPU:
		return "Virtual GPU"
	case .CPU:
		return "CPU"
	case .OTHER:
		return "Other"
	}

	return "Unknown"
}
