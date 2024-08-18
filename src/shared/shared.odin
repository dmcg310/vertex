package shared

// SHARED PACKAGE TO AVOID CYCLIC DEPENDENCIES

import "vendor:glfw"
import vk "vendor:vulkan"

MAX_FRAMES_IN_FLIGHT :: 2

QueueFamily :: enum {
	Graphics,
	Present,
}

QueueFamilyIndices :: struct {
	data: [QueueFamily]int,
}

is_framebuffer_resized: bool = false

find_queue_families :: proc(
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

framebuffer_size_callback :: proc "c" (
	window: glfw.WindowHandle,
	width, height: i32,
) {
	is_framebuffer_resized = true
}
