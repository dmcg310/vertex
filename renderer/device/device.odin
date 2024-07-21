package device

import "../instance"
import "../shared"
import "../swapchain"
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
	indices := shared.find_queue_families(
		device.physical_device,
		surface.surface,
	)

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
}

create_surface :: proc(
	_instance: instance.Instance,
	_window: ^window.Window,
) -> Surface {
	surface := Surface{}
	surface.surface = window.create_surface(_instance.instance, _window)

	return surface
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
		swap_chain_support := swapchain.query_swap_chain_support(
			device,
			surface,
		)
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
