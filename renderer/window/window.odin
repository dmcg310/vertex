package window

import "../util"
import "core:fmt"
import "vendor:glfw"
import vk "vendor:vulkan"

Window :: struct {
	handle:  glfw.WindowHandle,
	surface: vk.SurfaceKHR,
}

init_window :: proc(width, height: i32, title: string) -> Window {
	window := Window{}

	if !glfw.Init() {
		panic("Failed to initialize GLFW")
	}

	if window.handle = glfw.CreateWindow(
		width,
		height,
		util.to_cstring(title),
		nil,
		nil,
	); window.handle == nil {
		panic("Failed to create GLFW window")
	}

	glfw.WindowHint(glfw.CLIENT_API, glfw.NO_API)
	glfw.SetFramebufferSizeCallback(window.handle, framebuffer_size_callback)

	fmt.println("Window initialized")

	return window
}

is_window_closed :: proc(window: Window) -> bool {
	return bool(glfw.WindowShouldClose(window.handle))
}

poll_window_events :: proc() {
	glfw.PollEvents()
}

// create_surface :: proc(
// 	instance: vk.Instance,
// 	window: Window,
// ) -> vk.SurfaceKHR {
// 	surface: vk.SurfaceKHR
// 	if glfw.CreateWindowSurface(instance, window.handle, nil, &surface) {
// 		fmt.println("Failed to create window surface")
// 	}
// 	return surface
// }

// destroy_surface :: proc(instance: vk.Instance, window: Window) {
// 	vk.DestroySurfaceKHR(instance, window.surface, nil)
// }

destroy_window :: proc(window: Window) {
	glfw.DestroyWindow(window.handle)
	glfw.Terminate()

	fmt.println("Window destroyed")
}

@(private)
framebuffer_size_callback :: proc "c" (
	window: glfw.WindowHandle,
	width, height: i32,
) {
	// TODO vulkan specific context
}
