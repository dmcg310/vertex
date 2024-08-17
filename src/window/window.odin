package window

import "../log"
import "../util"
import "vendor:glfw"
import vk "vendor:vulkan"

Window :: struct {
	handle:          glfw.WindowHandle,
	surface_created: bool,
}

framebuffer_resized: bool

init_window :: proc(width, height: i32, title: string) -> Window {
	window := Window{}

	if !glfw.Init() {
		log.log_fatal("Failed to initialize GLFW")
	}

	glfw.WindowHint(glfw.CLIENT_API, glfw.NO_API)

	cstr_title := util.to_cstring(title)
	defer delete(cstr_title)

	if window.handle = glfw.CreateWindow(
		width,
		height,
		cstr_title,
		nil,
		nil,
	); window.handle == nil {
		log.log_fatal("Failed to create GLFW window")
	}

	glfw.SetFramebufferSizeCallback(window.handle, framebuffer_size_callback)
	glfw.SetKeyCallback(window.handle, key_callback)

	log.log("Window created")

	return window
}

get_framebuffer_size :: proc(window: Window) -> (i32, i32) {
	return glfw.GetFramebufferSize(window.handle)
}

is_window_closed :: proc(window: Window) -> bool {
	return bool(glfw.WindowShouldClose(window.handle))
}

poll_window_events :: proc() {
	glfw.PollEvents()
}

wait_events :: proc() {
	glfw.WaitEvents()
}

create_surface :: proc(
	instance: vk.Instance,
	window: ^Window,
) -> vk.SurfaceKHR {
	if window.surface_created {
		log.log_fatal("Surface for this window already created")
	}

	surface: vk.SurfaceKHR
	if err := glfw.CreateWindowSurface(instance, window.handle, nil, &surface);
	   err != .SUCCESS {
		log.log_fatal_with_vk_result("Failed to create window surface", err)
	}

	log.log("Vulkan surface created")

	window.surface_created = true

	return surface
}

destroy_surface :: proc(
	surface: vk.SurfaceKHR,
	instance: vk.Instance,
	window: ^Window,
) {
	if window.surface_created {
		vk.DestroySurfaceKHR(instance, surface, nil)

		log.log("Vulkan surface destroyed")

		window.surface_created = false
	}
}

destroy_window :: proc(window: Window) {
	glfw.DestroyWindow(window.handle)
	glfw.Terminate()

	log.log("Window destroyed")
}

@(private)
key_callback :: proc "c" (
	window: glfw.WindowHandle,
	key, scancode, action, mods: i32,
) {
	if key == glfw.KEY_ESCAPE && action == glfw.PRESS {
		glfw.SetWindowShouldClose(window, true)
	}
}

@(private)
framebuffer_size_callback :: proc "c" (
	window: glfw.WindowHandle,
	width, height: i32,
) {
	framebuffer_resized = true
}
