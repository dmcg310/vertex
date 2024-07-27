package window

import "../util"
import "core:fmt"
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
		panic("Failed to initialize GLFW")
	}

	glfw.WindowHint(glfw.CLIENT_API, glfw.NO_API)

	if window.handle = glfw.CreateWindow(
		width,
		height,
		util.to_cstring(title),
		nil,
		nil,
	); window.handle == nil {
		panic("Failed to create GLFW window")
	}

	glfw.SetFramebufferSizeCallback(window.handle, framebuffer_size_callback)

	fmt.println("Window created")

	return window
}

get_framebuffer_size :: proc(window: Window) -> (i32, i32) {
	width, height := glfw.GetFramebufferSize(window.handle)

	return width, height
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
		panic("Surface for this window already created")
	}

	surface: vk.SurfaceKHR
	if err := glfw.CreateWindowSurface(instance, window.handle, nil, &surface);
	   err != vk.Result.SUCCESS {
		fmt.println("Result: ", err)
		panic("Failed to create window surface")
	}

	fmt.println("Vulkan surface created")

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

		fmt.println("Vulkan surface destroyed")

		window.surface_created = false
	}
}

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
	framebuffer_resized = true
}
