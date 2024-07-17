package device

import "core:fmt"
import vk "vendor:vulkan"

Device :: struct {
	physical_device: vk.PhysicalDevice,
}

QueueFamily :: enum {
	Graphics,
	Present,
}

QueueFamilyIndices :: struct {
	data: [QueueFamily]int,
}


pick_physical_device :: proc(instance: vk.Instance) {
	device := Device{}
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
		score := is_device_suitable(_device)
		if score > highest_score {
			device.physical_device = _device
			highest_score = score
		}
	}

	if highest_score == 0 {
		panic("Failed to find a suitable GPU")
	}

	if device.physical_device == nil {
		panic("Failed to find a suitable GPU")
	}
}

@(private)
is_device_suitable :: proc(device: vk.PhysicalDevice) -> int {
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

	// if !check_device_extension_support(device) {
	//     return 0
	// }


	return score
}

@(private)
find_queue_families :: proc(device: vk.PhysicalDevice) -> QueueFamilyIndices {
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
	}

	return indices
}
