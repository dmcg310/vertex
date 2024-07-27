package command

import "../shared"
import "../swapchain"
import vk "vendor:vulkan"

CommandPool :: struct {
	pool: vk.CommandPool,
}

create_command_pool :: proc(
	device: vk.Device,
	swap_chain: swapchain.SwapChain,
) -> CommandPool {
	command_pool := CommandPool{}

	pool_info := vk.CommandPoolCreateInfo{}
	pool_info.sType = vk.StructureType.COMMAND_POOL_CREATE_INFO
	pool_info.flags = vk.CommandPoolCreateFlags{.RESET_COMMAND_BUFFER}
	pool_info.queueFamilyIndex = swap_chain.queue_family_indices[0]

	if vk.CreateCommandPool(device, &pool_info, nil, &command_pool.pool) !=
	   vk.Result.SUCCESS {
		panic("failed to create command pool")
	}

	return command_pool
}

destroy_command_pool :: proc(pool: ^CommandPool, device: vk.Device) {
	vk.DestroyCommandPool(device, pool.pool, nil)
}
