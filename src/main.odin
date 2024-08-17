package main

import "core:fmt"
import "core:mem"
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
	when ODIN_DEBUG {
		track: mem.Tracking_Allocator
		mem.tracking_allocator_init(&track, context.allocator)
		context.allocator = mem.tracking_allocator(&track)

		defer {
			alloc_map_len := len(track.allocation_map)
			bad_free_array_len := len(track.bad_free_array)

			if alloc_map_len == 0 && bad_free_array_len == 0 {
				log.log("Every malloc was freed!", "INFO")
			}

			if alloc_map_len > 0 {
				fmt.eprintf(
					"=== %v allocations not freed: ===\n",
					alloc_map_len,
				)

				for _, entry in track.allocation_map {
					fmt.eprintf(
						"- %v bytes @ %v\n",
						entry.size,
						entry.location,
					)
				}
			}

			if bad_free_array_len > 0 {
				fmt.eprintf(
					"=== %v incorrect frees: ===\n",
					bad_free_array_len,
				)

				for entry in track.bad_free_array {
					fmt.eprintf("- %p @ %v\n", entry.memory, entry.location)
				}
			}

			mem.tracking_allocator_destroy(&track)
		}
	}

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

	free_all(context.temp_allocator)
}
