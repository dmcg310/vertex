package main

import "core:fmt"
import "core:os"
import "log"
import "renderer"
import "window"

Application :: struct {
	width:     i32,
	height:    i32,
	title:     string,
	_renderer: renderer.Renderer,
}

main :: proc() {
	application := init_application()
	run_application(&application)
	shutdown_application(&application)
}

init_application :: proc() -> Application {
	application := Application {
		width  = 1600,
		height = 900,
		title  = "Vertex",
	}

	if err := log.init_logger(); err != os.ERROR_NONE {
		fmt.eprintln("Failed to initialize logger", err)
		os.exit(1)
	}

	if err := log.init_vulkan_logger(); err != os.ERROR_NONE {
		log.log_fatal("Failed to initialize Vulkan logger")
		os.exit(1)
	}

	renderer.init_renderer(
		&application._renderer,
		application.width,
		application.height,
		application.title,
	)

	return application
}

run_application :: proc(application: ^Application) {
	for !window.is_window_closed(application._renderer._window) {
		window.poll_window_events()

		renderer.render(&application._renderer)
	}
}

shutdown_application :: proc(application: ^Application) {
	renderer.shutdown_renderer(&application._renderer)

	log.close_logger()
	log.close_vulkan_logger()
}
