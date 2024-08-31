package renderer

import "base:runtime"

import im "../../external/odin-imgui"
import vk "vendor:vulkan"

import "../../external/odin-imgui/imgui_impl_glfw"
import "../../external/odin-imgui/imgui_impl_vulkan"
import "../util"

@(private = "file")
_resources: RendererResources

@(private = "file")
cached_model_names: []string

@(private = "file")
cached_shader_names: []string

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

	cache_entries("assets/models", "Models")
	cache_entries("assets/shaders", "Shaders")

	log("ImGui context initialized")
}

imgui_new_frame :: proc() {
	imgui_impl_vulkan.NewFrame()
	imgui_impl_glfw.NewFrame()
	im.NewFrame()

	window_flags: im.WindowFlags = {.NoMove, .NoTitleBar}

	viewport := im.GetMainViewport()

	if restore_ui_size_defaults {
		padding: f32 = 12.0

		window_size: Vec2
		window_pos: Vec2

		window_size.x = viewport.Size.x * 0.10
		window_size.y = viewport.Size.y - (padding * 2)
		window_pos.x = viewport.Pos.x + padding
		window_pos.y = viewport.Pos.y + padding

		im.SetNextWindowPos(window_pos)
		im.SetNextWindowSize(window_size)
		im.SetNextWindowViewport(viewport._ID)

		restore_ui_size_defaults = false
	} else {
		im.SetNextWindowViewport(viewport._ID)
	}

	if im.Begin("Options", nil, window_flags) {
		im.Text("Options")

		if im.CollapsingHeader("Assets") {
			append_assets_node("Models", "assets/models", cached_model_names)
			append_assets_node(
				"Shaders",
				"assets/shaders",
				cached_shader_names,
			)
		}
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
append_assets_node :: proc(name, seperator_text: cstring, entries: []string) {
	if im.TreeNode(name) {
		im.SeparatorText(seperator_text)

		if len(entries) == 0 {
			im.Selectable("None found!", false, {.Disabled})
		}

		for name in entries {
			im.Selectable(util.to_cstring(name))
		}

		im.Spacing()
		im.TreePop()
	}
}

@(private = "file")
cache_entries :: proc(path: string, name: string) {
	entries, list_ok, error := util.list_entries_in_dir(path)
	if !list_ok {
		log(error, "WARNING")
	}

	switch name {
	case "Models":
		cached_model_names = model_entries_filter(entries)
	case "Shaders":
		cached_shader_names = shader_entries_filter(entries)
	}
}

@(private = "file")
check_vk_result :: proc "c" (result: vk.Result) {
	if result != .SUCCESS {
		context = runtime.default_context()
		log_fatal_with_vk_result("Imgui vulkan error", result)
	}
}
