package renderer


import ovma "../../external/odin-vma"
import vk "vendor:vulkan"

VMAAllocator :: struct {
	allocator: ovma.Allocator,
}

VMAAllocation :: struct {
	allocation: ovma.Allocation,
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

vma_buffer_create :: proc(
	vma_allocator: VMAAllocator,
	size: vk.DeviceSize,
	usage: vk.BufferUsageFlags,
	memory_usage: ovma.MemoryUsage,
	flags: ovma.AllocationCreateFlags,
) -> (
	buffer: vk.Buffer,
	vma_allocation: VMAAllocation,
) {
	allocation := VMAAllocation{}

	buffer_create_info := vk.BufferCreateInfo {
		sType = .BUFFER_CREATE_INFO,
		size  = size,
		usage = usage,
	}

	allocation_create_info := ovma.AllocationCreateInfo {
		usage = memory_usage,
		flags = flags,
	}

	if result := ovma.CreateBuffer(
		vma_allocator.allocator,
		&buffer_create_info,
		&allocation_create_info,
		&buffer,
		&allocation.allocation,
		nil,
	); result != .SUCCESS {
		log_fatal_with_vk_result("Failed to create buffer", result)
	}

	return buffer, allocation
}

vma_buffer_destroy :: proc(
	vma_allocator: VMAAllocator,
	buffer: vk.Buffer,
	vma_allocation: VMAAllocation,
) {
	ovma.DestroyBuffer(
		vma_allocator.allocator,
		buffer,
		vma_allocation.allocation,
	)
}

vma_map_memory :: proc(
	vma_allocator: VMAAllocator,
	vma_allocation: VMAAllocation,
) -> rawptr {
	mapped_data: rawptr
	if result := ovma.MapMemory(
		vma_allocator.allocator,
		vma_allocation.allocation,
		&mapped_data,
	); result != .SUCCESS {
		log_fatal_with_vk_result("Failed to map memory", result)
	}

	return mapped_data
}

vma_unmap_memory :: proc(
	vma_allocator: VMAAllocator,
	vma_allocation: VMAAllocation,
) {
	ovma.UnmapMemory(vma_allocator.allocator, vma_allocation.allocation)
}

vma_flush_allocation :: proc(
	vma_allocator: VMAAllocator,
	vma_allocation: VMAAllocation,
	offset: vk.DeviceSize,
	size: vk.DeviceSize,
) {
	if result := ovma.FlushAllocation(
		vma_allocator.allocator,
		vma_allocation.allocation,
		offset,
		size,
	); result != .SUCCESS {
		log_fatal_with_vk_result("Failed to flush allocation", result)
	}
}

vma_invalidate_allocation :: proc(
	vma_allocator: VMAAllocator,
	vma_allocation: VMAAllocation,
	offset: vk.DeviceSize,
	size: vk.DeviceSize,
) {
	if result := ovma.InvalidateAllocation(
		vma_allocator.allocator,
		vma_allocation.allocation,
		offset,
		size,
	); result != .SUCCESS {
		log_fatal_with_vk_result("Failed to invalidate allocation", result)
	}
}
