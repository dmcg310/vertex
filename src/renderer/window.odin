package renderer

import "vendor:glfw"

import vk "vendor:vulkan"

import "../util"

Window :: struct {
	handle:          glfw.WindowHandle,
	surface_created: bool,
	is_hidden:       bool,
}

is_framebuffer_resized: bool

window_create :: proc(width, height: i32, title: string) -> Window {
	window := Window{}

	if !glfw.Init() {
		log_fatal("Failed to initialize GLFW")
	}

	glfw.WindowHint(glfw.CLIENT_API, glfw.NO_API)
	glfw.WindowHint(glfw.VISIBLE, glfw.FALSE)

	if window.handle = glfw.CreateWindow(
		width,
		height,
		util.to_cstring(title),
		nil,
		nil,
	); window.handle == nil {
		log_fatal("Failed to create GLFW window")
	}

	glfw.MaximizeWindow(window.handle)

	glfw.SetFramebufferSizeCallback(window.handle, framebuffer_size_callback)
	glfw.SetKeyCallback(window.handle, key_callback)

	window.is_hidden = true

	log("Window created")

	return window
}

window_toggle_visibility :: proc(window: Window) {
	if window.is_hidden {
		glfw.ShowWindow(window.handle)
	} else {
		glfw.HideWindow(window.handle)
	}
}

window_get_framebuffer_size :: proc(window: Window) -> (i32, i32) {
	return glfw.GetFramebufferSize(window.handle)
}

window_is_closed :: proc(window: Window) -> bool {
	return bool(glfw.WindowShouldClose(window.handle))
}

window_poll_events :: proc() {
	glfw.PollEvents()
}

window_wait_events :: proc() {
	glfw.WaitEvents()
}

window_create_surface :: proc(
	instance: vk.Instance,
	window: ^Window,
) -> vk.SurfaceKHR {
	if window.surface_created {
		log_fatal("Surface for this window already created")
	}

	surface: vk.SurfaceKHR
	if err := glfw.CreateWindowSurface(instance, window.handle, nil, &surface);
	   err != .SUCCESS {
		log_fatal_with_vk_result("Failed to create window surface", err)
	}

	log("Vulkan surface created")

	window.surface_created = true

	return surface
}

window_destroy_surface :: proc(
	surface: vk.SurfaceKHR,
	instance: vk.Instance,
	window: ^Window,
) {
	if window.surface_created {
		vk.DestroySurfaceKHR(instance, surface, nil)

		log("Vulkan surface destroyed")

		window.surface_created = false
	}
}

window_destroy :: proc(window: Window) {
	glfw.DestroyWindow(window.handle)
	glfw.Terminate()

	log("Window destroyed")
}

framebuffer_size_callback :: proc "c" (
	window: glfw.WindowHandle,
	width, height: i32,
) {
	is_framebuffer_resized = true
}

@(private = "file")
key_callback :: proc "c" (
	window: glfw.WindowHandle,
	key, scancode, action, mods: i32,
) {
	if key == glfw.KEY_ESCAPE && action == glfw.PRESS {
		glfw.SetWindowShouldClose(window, true)
	}
}
