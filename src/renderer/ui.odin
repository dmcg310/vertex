package renderer

import "base:runtime"
import "vendor:glfw"

import im "../../external/odin-imgui"
import vk "vendor:vulkan"

import "../../external/odin-imgui/imgui_impl_glfw"
import "../../external/odin-imgui/imgui_impl_vulkan"

@(private = "file")
_resources: RendererResources

restore_ui_size_defaults: bool = true

imgui_init :: proc(resources: RendererResources) {
	_resources = resources

	im.CHECKVERSION()
	im.CreateContext()
	io := im.GetIO()
	io.IniFilename = nil
	io.ConfigFlags += {.NavEnableKeyboard, .NavEnableGamepad}
	when im.IMGUI_BRANCH == "docking" {
		io.ConfigFlags += {.DockingEnable}
		io.ConfigFlags += {.ViewportsEnable}

		style := im.GetStyle()
		style.WindowRounding = 0
		style.Colors[im.Col.WindowBg].w = 1
	}

	im.StyleColorsDark()

	imgui_impl_glfw.InitForVulkan(resources.window.handle, true)

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
		rawptr(resources.instance.instance),
	)

	init_info := imgui_impl_vulkan.InitInfo {
		Instance              = resources.instance.instance,
		PhysicalDevice        = resources.device.physical_device,
		Device                = resources.device.logical_device,
		QueueFamily           = resources.device.graphics_family_index,
		Queue                 = resources.device.graphics_queue,
		PipelineCache         = {},
		DescriptorPool        = resources.descriptor_pool.imgui_pool,
		MinImageCount         = u32(len(resources.swap_chain.images)),
		ImageCount            = u32(len(resources.swap_chain.images)),
		MSAASamples           = vk.SampleCountFlags{._1},
		Allocator             = nil,
		CheckVkResultFn       = check_vk_result,
		ColorAttachmentFormat = resources.swap_chain.format.format,
	}
	imgui_impl_vulkan.Init(&init_info, resources.pipeline.render_pass)

	command_buffer := command_begin_single_time(
		resources.device.logical_device,
		resources.command_pool.pool,
	)
	imgui_impl_vulkan.CreateFontsTexture()

	command_end_single_time(
		resources.device.logical_device,
		resources.command_pool.pool,
		resources.device.graphics_queue,
		&command_buffer,
	)
	imgui_impl_vulkan.DestroyFontsTexture()

	log("ImGui context initialized")
}

imgui_new_frame :: proc() {
	imgui_impl_vulkan.NewFrame()
	imgui_impl_glfw.NewFrame()
	im.NewFrame()

	dockspace_flags: im.DockNodeFlags = {.PassthruCentralNode}
	window_flags: im.WindowFlags = {.NoMove, .NoTitleBar}

	viewport := im.GetMainViewport()

	if restore_ui_size_defaults {
		window_size: Vec2
		window_pos: Vec2

		window_size.x = viewport.Size.x * 0.10
		window_size.y = viewport.Size.y
		window_pos.x = viewport.Pos.x
		window_pos.y = viewport.Pos.y

		im.SetNextWindowPos(window_pos)
		im.SetNextWindowSize(window_size)
		im.SetNextWindowViewport(viewport._ID)

		restore_ui_size_defaults = false
	} else {
		im.SetNextWindowViewport(viewport._ID)
	}

	im.Begin("Dockspace", nil, window_flags)
	defer im.End()

	dockspace_id := im.GetID("Dockspace")
	im.DockSpace(dockspace_id, {0, 0}, dockspace_flags)

	if im.Begin("Window 1", nil) {
		im.Text("This is window 1")
	}
	im.End()
}

imgui_render :: proc(command_buffer: vk.CommandBuffer) {
	im.Render()
	imgui_impl_vulkan.RenderDrawData(im.GetDrawData(), command_buffer)

	when im.IMGUI_BRANCH == "docking" {
		im.UpdatePlatformWindows()
		im.RenderPlatformWindowsDefault()
	}
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
