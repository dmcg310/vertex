package renderer

import "base:runtime"
import "vendor:glfw"

import im "../../external/odin-imgui"
import vk "vendor:vulkan"

import "../../external/odin-imgui/imgui_impl_glfw"
import "../../external/odin-imgui/imgui_impl_vulkan"

ImGuiState :: struct {
	descriptor_pool: vk.DescriptorPool,
}

imgui_init :: proc(
	window: glfw.WindowHandle,
	render_pass: vk.RenderPass,
	device: vk.Device,
	physical_device: vk.PhysicalDevice,
	instance: vk.Instance,
	queue: vk.Queue,
	queue_family: u32,
	swap_chain_image_count: u32,
	swap_chain_format: vk.Format,
	command_pool: vk.CommandPool,
) -> ImGuiState {
	im.CHECKVERSION()
	im.CreateContext()
	io := im.GetIO()
	io.IniFilename = nil
	io.ConfigFlags += {.NavEnableKeyboard, .NavEnableGamepad, .DockingEnable}

	im.StyleColorsDark()

	style := im.GetStyle()
	if .ViewportsEnable in io.ConfigFlags {
		style.WindowRounding = 0
		style.Colors[im.Col.WindowBg].w = 1
	}

	imgui_impl_glfw.InitForVulkan(window, true)

	imgui_impl_vulkan.LoadFunctions(
		proc "c" (
			function_name: cstring,
			user_data: rawptr,
		) -> vk.ProcVoidFunction {
			return vk.GetInstanceProcAddr(
				cast(vk.Instance)user_data,
				function_name,
			)
		},
		rawptr(instance),
	)

	descriptor_pool := imgui_create_descriptor_pool(device)

	init_info := imgui_impl_vulkan.InitInfo {
		Instance              = instance,
		PhysicalDevice        = physical_device,
		Device                = device,
		QueueFamily           = queue_family,
		Queue                 = queue,
		PipelineCache         = {},
		DescriptorPool        = descriptor_pool,
		MinImageCount         = swap_chain_image_count,
		ImageCount            = swap_chain_image_count,
		MSAASamples           = vk.SampleCountFlags{._1},
		Allocator             = nil,
		CheckVkResultFn       = check_vk_result,
		ColorAttachmentFormat = swap_chain_format,
	}
	imgui_impl_vulkan.Init(&init_info, render_pass)

	command_buffer := imgui_begin_single_time_commands(device, command_pool)
	imgui_impl_vulkan.CreateFontsTexture()

	imgui_end_single_time_commands(
		device,
		command_pool,
		&command_buffer,
		queue,
	)
	imgui_impl_vulkan.DestroyFontsTexture()

	log("ImGui context initialized")

	return ImGuiState{descriptor_pool = descriptor_pool}
}

imgui_new_frame :: proc() {
	imgui_impl_vulkan.NewFrame()
	imgui_impl_glfw.NewFrame()
	im.NewFrame()
}

imgui_render :: proc(command_buffer: vk.CommandBuffer) {
	im.Render()
	imgui_impl_vulkan.RenderDrawData(im.GetDrawData(), command_buffer)
}

imgui_update_platform_windows :: proc() {
	if .ViewportsEnable in im.GetIO().ConfigFlags {
		im.UpdatePlatformWindows()
		im.RenderPlatformWindowsDefault()
	}
}

imgui_destroy :: proc(device: vk.Device, imgui_state: ImGuiState) {
	vk.DestroyDescriptorPool(device, imgui_state.descriptor_pool, nil)
	imgui_impl_vulkan.Shutdown()
	imgui_impl_glfw.Shutdown()
	im.DestroyContext()

	log("ImGui context destroyed")
}

@(private)
imgui_begin_single_time_commands :: proc(
	device: vk.Device,
	pool: vk.CommandPool,
) -> vk.CommandBuffer {
	alloc_info := vk.CommandBufferAllocateInfo {
		sType              = .COMMAND_BUFFER_ALLOCATE_INFO,
		level              = .PRIMARY,
		commandPool        = pool,
		commandBufferCount = 1,
	}

	command_buffer: vk.CommandBuffer
	vk.AllocateCommandBuffers(device, &alloc_info, &command_buffer)

	begin_info := vk.CommandBufferBeginInfo {
		sType = .COMMAND_BUFFER_BEGIN_INFO,
		flags = {.ONE_TIME_SUBMIT},
	}

	vk.BeginCommandBuffer(command_buffer, &begin_info)

	return command_buffer
}

@(private)
imgui_end_single_time_commands :: proc(
	device: vk.Device,
	pool: vk.CommandPool,
	command_buffer: ^vk.CommandBuffer,
	queue: vk.Queue,
) {
	vk.EndCommandBuffer(command_buffer^)

	submit_info := vk.SubmitInfo {
		sType              = .SUBMIT_INFO,
		commandBufferCount = 1,
		pCommandBuffers    = command_buffer,
	}

	vk.QueueSubmit(queue, 1, &submit_info, {})
	vk.QueueWaitIdle(queue)

	vk.FreeCommandBuffers(device, pool, 1, command_buffer)
}

@(private)
imgui_create_descriptor_pool :: proc(device: vk.Device) -> vk.DescriptorPool {
	pool_sizes := []vk.DescriptorPoolSize {
		{type = .SAMPLER, descriptorCount = 1000},
		{type = .COMBINED_IMAGE_SAMPLER, descriptorCount = 1000},
		{type = .SAMPLED_IMAGE, descriptorCount = 1000},
		{type = .STORAGE_IMAGE, descriptorCount = 1000},
		{type = .UNIFORM_TEXEL_BUFFER, descriptorCount = 1000},
		{type = .STORAGE_TEXEL_BUFFER, descriptorCount = 1000},
		{type = .UNIFORM_BUFFER, descriptorCount = 1000},
		{type = .STORAGE_BUFFER, descriptorCount = 1000},
		{type = .UNIFORM_BUFFER_DYNAMIC, descriptorCount = 1000},
		{type = .STORAGE_BUFFER_DYNAMIC, descriptorCount = 1000},
		{type = .INPUT_ATTACHMENT, descriptorCount = 1000},
	}

	pool_info := vk.DescriptorPoolCreateInfo {
		sType         = .DESCRIPTOR_POOL_CREATE_INFO,
		flags         = {.FREE_DESCRIPTOR_SET},
		maxSets       = 1000 * u32(len(pool_sizes)),
		poolSizeCount = u32(len(pool_sizes)),
		pPoolSizes    = raw_data(pool_sizes),
	}

	descriptor_pool: vk.DescriptorPool
	if result := vk.CreateDescriptorPool(
		device,
		&pool_info,
		nil,
		&descriptor_pool,
	); result != .SUCCESS {
		log_fatal_with_vk_result(
			"Failed to create descriptor pool for ImGui",
			result,
		)
	}

	return descriptor_pool
}

@(private)
check_vk_result :: proc "c" (result: vk.Result) {
	if result != .SUCCESS {
		context = runtime.default_context()
		log_fatal_with_vk_result("Imgui vulkan error", result)
	}
}
