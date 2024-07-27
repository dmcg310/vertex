package synchronization

import "../shared"
import "core:fmt"
import vk "vendor:vulkan"

SyncObject :: struct {
	image_available_semaphores: [shared.MAX_FRAMES_IN_FLIGHT]vk.Semaphore,
	render_finished_semaphores: [shared.MAX_FRAMES_IN_FLIGHT]vk.Semaphore,
	in_flight_fences:           [shared.MAX_FRAMES_IN_FLIGHT]vk.Fence,
}

create_sync_objects :: proc(device: vk.Device) -> SyncObject {
	sync_object := SyncObject{}

	semaphore_info := vk.SemaphoreCreateInfo{}
	semaphore_info.sType = vk.StructureType.SEMAPHORE_CREATE_INFO

	fence_info := vk.FenceCreateInfo{}
	fence_info.sType = vk.StructureType.FENCE_CREATE_INFO

	// Signaled so that the first frame isn't waiting on the last frame - which doesn't exist
	fence_info.flags = vk.FenceCreateFlags{.SIGNALED}

	for i := 0; i < shared.MAX_FRAMES_IN_FLIGHT; i += 1 {
		if vk.CreateSemaphore(
			   device,
			   &semaphore_info,
			   nil,
			   &sync_object.image_available_semaphores[i],
		   ) !=
			   vk.Result.SUCCESS ||
		   vk.CreateSemaphore(
			   device,
			   &semaphore_info,
			   nil,
			   &sync_object.render_finished_semaphores[i],
		   ) !=
			   vk.Result.SUCCESS ||
		   vk.CreateFence(
			   device,
			   &fence_info,
			   nil,
			   &sync_object.in_flight_fences[i],
		   ) !=
			   vk.Result.SUCCESS {
			panic("Failed to create synchronization objects for a frame")
		}
	}

	fmt.println("Vulkan synchronization objects created")

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

	fmt.println("Vulkan synchronization objects destroyed")
}
