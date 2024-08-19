package renderer

import vk "vendor:vulkan"

SyncObject :: struct {
	image_available_semaphores: [MAX_FRAMES_IN_FLIGHT]vk.Semaphore,
	render_finished_semaphores: [MAX_FRAMES_IN_FLIGHT]vk.Semaphore,
	in_flight_fences:           [MAX_FRAMES_IN_FLIGHT]vk.Fence,
}

sync_objects_create :: proc(device: vk.Device) -> SyncObject {
	sync_object := SyncObject{}

	semaphore_info := vk.SemaphoreCreateInfo {
		sType = .SEMAPHORE_CREATE_INFO,
	}

	fence_info := vk.FenceCreateInfo {
		sType = .FENCE_CREATE_INFO,
		flags = {.SIGNALED},
	}

	for i := 0; i < MAX_FRAMES_IN_FLIGHT; i += 1 {
		result: vk.Result

		result = vk.CreateSemaphore(
			device,
			&semaphore_info,
			nil,
			&sync_object.image_available_semaphores[i],
		)
		if result != .SUCCESS {
			log_fatal_with_vk_result(
				"Failed to create image available semaphore",
				result,
			)
		}

		result = vk.CreateSemaphore(
			device,
			&semaphore_info,
			nil,
			&sync_object.render_finished_semaphores[i],
		)
		if result != .SUCCESS {
			log_fatal_with_vk_result(
				"Failed to create render finished semaphore",
				result,
			)
		}

		result = vk.CreateFence(
			device,
			&fence_info,
			nil,
			&sync_object.in_flight_fences[i],
		)
		if result != .SUCCESS {
			log_fatal_with_vk_result(
				"Failed to create in-flight fence",
				result,
			)
		}
	}

	log("Vulkan synchronization objects created")

	return sync_object
}

sync_objects_destroy :: proc(sync_object: ^SyncObject, device: vk.Device) {
	for i := 0; i < MAX_FRAMES_IN_FLIGHT; i += 1 {
		vk.DestroySemaphore(
			device,
			sync_object.image_available_semaphores[i],
			nil,
		)

		vk.DestroySemaphore(
			device,
			sync_object.render_finished_semaphores[i],
			nil,
		)

		vk.DestroyFence(device, sync_object.in_flight_fences[i], nil)
	}

	log("Vulkan synchronization objects destroyed")
}

sync_wait :: proc(device: vk.Device, fence: ^vk.Fence) -> bool {
	result := vk.WaitForFences(device, 1, fence, true, ~u64(0))

	if result == .ERROR_OUT_OF_DATE_KHR {
		return false
	} else if result != .SUCCESS && result != .TIMEOUT {
		log_fatal("Failed to wait for fences")
	}

	return true
}

sync_reset_fence :: proc(device: vk.Device, fence: ^vk.Fence) {
	vk.ResetFences(device, 1, fence)
}
