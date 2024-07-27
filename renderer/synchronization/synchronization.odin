package synchronization

import "core:fmt"
import vk "vendor:vulkan"

SyncObject :: struct {
	image_available_semaphore: vk.Semaphore,
	render_finished_semaphore: vk.Semaphore,
	in_flight_fence:           vk.Fence,
}

create_sync_object :: proc(device: vk.Device) -> SyncObject {
	sync_object := SyncObject{}

	semaphore_info := vk.SemaphoreCreateInfo{}
	semaphore_info.sType = vk.StructureType.SEMAPHORE_CREATE_INFO

	fence_info := vk.FenceCreateInfo{}
	fence_info.sType = vk.StructureType.FENCE_CREATE_INFO

	// Signaled so that the first frame isn't waiting on the last frame - which doesn't exist
	fence_info.flags = vk.FenceCreateFlags{.SIGNALED}

	if vk.CreateSemaphore(
		   device,
		   &semaphore_info,
		   nil,
		   &sync_object.image_available_semaphore,
	   ) !=
		   vk.Result.SUCCESS ||
	   vk.CreateSemaphore(
		   device,
		   &semaphore_info,
		   nil,
		   &sync_object.render_finished_semaphore,
	   ) !=
		   vk.Result.SUCCESS ||
	   vk.CreateFence(
		   device,
		   &fence_info,
		   nil,
		   &sync_object.in_flight_fence,
	   ) !=
		   vk.Result.SUCCESS {
		panic("Failed to create synchronization objects for a frame")
	}

	fmt.println("Vulkan synchronization objects created")

	return sync_object
}

destroy_sync_object :: proc(sync_object: ^SyncObject, device: vk.Device) {
	vk.DestroySemaphore(device, sync_object.image_available_semaphore, nil)
	vk.DestroySemaphore(device, sync_object.render_finished_semaphore, nil)
	vk.DestroyFence(device, sync_object.in_flight_fence, nil)

	fmt.println("Vulkan synchronization objects destroyed")
}
