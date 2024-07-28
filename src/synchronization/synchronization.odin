package synchronization

import "../log"
import "../shared"
import vk "vendor:vulkan"

SyncObject :: struct {
	image_available_semaphores: [shared.MAX_FRAMES_IN_FLIGHT]vk.Semaphore,
	render_finished_semaphores: [shared.MAX_FRAMES_IN_FLIGHT]vk.Semaphore,
	in_flight_fences:           [shared.MAX_FRAMES_IN_FLIGHT]vk.Fence,
}

create_sync_objects :: proc(device: vk.Device) -> SyncObject {
	sync_object := SyncObject{}

	semaphore_info := vk.SemaphoreCreateInfo {
		sType = .SEMAPHORE_CREATE_INFO,
	}

	fence_info := vk.FenceCreateInfo {
		sType = .FENCE_CREATE_INFO,
		flags = {.SIGNALED},
	}

	for i := 0; i < shared.MAX_FRAMES_IN_FLIGHT; i += 1 {
		result: vk.Result

		result = vk.CreateSemaphore(
			device,
			&semaphore_info,
			nil,
			&sync_object.image_available_semaphores[i],
		)
		if result != .SUCCESS {
			log.log_fatal_with_vk_result(
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
			log.log_fatal_with_vk_result(
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
			log.log_fatal_with_vk_result(
				"Failed to create in-flight fence",
				result,
			)
		}
	}

	log.log("Vulkan synchronization objects created")

	return sync_object
}

destroy_sync_objects :: proc(sync_object: ^SyncObject, device: vk.Device) {
	for i := 0; i < shared.MAX_FRAMES_IN_FLIGHT; i += 1 {
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

	log.log("Vulkan synchronization objects destroyed")
}
