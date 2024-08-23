package renderer


import ovma "../../external/odin-vma"
import vk "vendor:vulkan"

VMAAllocator :: struct {
	allocator: ovma.Allocator,
}

vma_init :: proc(device: Device, instance: Instance) -> VMAAllocator {
	vma_allocator := VMAAllocator{}

	vukan_functions := ovma.create_vulkan_functions()
	allocator_create_info := ovma.AllocatorCreateInfo {
		vulkanApiVersion = vk.API_VERSION_1_3,
		physicalDevice   = device.physical_device,
		device           = device.logical_device,
		instance         = instance.instance,
		pVulkanFunctions = &vukan_functions,
	}

	if result := ovma.CreateAllocator(
		&allocator_create_info,
		&vma_allocator.allocator,
	); result != .SUCCESS {
		log_fatal_with_vk_result("Failed to create VMA allocator", result)
	}

	log("Vukan memory allocator created")

	return vma_allocator
}

vma_destroy :: proc(vma_allocator: VMAAllocator) {
	ovma.DestroyAllocator(vma_allocator.allocator)

	log("Vukan memory allocator destroyed")
}
