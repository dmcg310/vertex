package renderer

import "base:runtime"
import "vendor:glfw"

import im "../../external/odin-imgui"
import vk "vendor:vulkan"

import "../../external/odin-imgui/imgui_impl_glfw"
import "../../external/odin-imgui/imgui_impl_vulkan"

imgui_init :: proc(
	window: glfw.WindowHandle,
	render_pass: vk.RenderPass,
	device: Device,
	instance: vk.Instance,
	swap_chain_image_count: u32,
	swap_chain_format: vk.Format,
	command_pool: vk.CommandPool,
	descriptor_pool: ^DescriptorPool,
) {
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

	init_info := imgui_impl_vulkan.InitInfo {
		Instance              = instance,
		PhysicalDevice        = device.physical_device,
		Device                = device.logical_device,
		QueueFamily           = device.graphics_family_index,
		Queue                 = device.graphics_queue,
		PipelineCache         = {},
		DescriptorPool        = descriptor_pool.imgui_pool,
		MinImageCount         = swap_chain_image_count,
		ImageCount            = swap_chain_image_count,
		MSAASamples           = vk.SampleCountFlags{._1},
		Allocator             = nil,
		CheckVkResultFn       = check_vk_result,
		ColorAttachmentFormat = swap_chain_format,
	}
	imgui_impl_vulkan.Init(&init_info, render_pass)

	command_buffer := command_begin_single_time(
		device.logical_device,
		command_pool,
	)
	imgui_impl_vulkan.CreateFontsTexture()

	command_end_single_time(
		device.logical_device,
		command_pool,
		device.graphics_queue,
		&command_buffer,
	)
	imgui_impl_vulkan.DestroyFontsTexture()

	log("ImGui context initialized")
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

imgui_destroy :: proc(device: vk.Device) {
	imgui_impl_vulkan.Shutdown()
	imgui_impl_glfw.Shutdown()
	im.DestroyContext()

	log("ImGui context destroyed")
}

@(private = "file")
check_vk_result :: proc "c" (result: vk.Result) {
	if result != .SUCCESS {
		context = runtime.default_context()
		log_fatal_with_vk_result("Imgui vulkan error", result)
	}
}
