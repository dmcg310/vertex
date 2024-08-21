package main

import "core:fmt"
import "core:mem"
import "core:os"

import "renderer"

Application :: struct {
	width:    i32,
	height:   i32,
	title:    string,
	renderer: renderer.Renderer,
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
				renderer.log("Every malloc was freed!", "INFO")
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
	if err := renderer.logger_init(); err != os.ERROR_NONE {
		fmt.eprintln("Failed to initialize logger", err)
		os.exit(1)
	}

	if err := renderer.vulkan_logger_init(); err != os.ERROR_NONE {
		renderer.log_fatal("Failed to initialize Vulkan logger")
		os.exit(1)
	}

	application := Application {
		width  = 1920,
		height = 1080,
		title  = "Vertex",
	}

	config := renderer.RendererConfiguration {
		application.width,
		application.height,
		application.title,
		true,
	}

	renderer.renderer_init(&application.renderer, config)

	return application
}

run_application :: proc(application: ^Application) {
	for !renderer.window_is_closed(application.renderer.resources.window) {
		renderer.window_poll_events()
		renderer.render(&application.renderer)
	}
}

shutdown_application :: proc(application: ^Application) {
	renderer.renderer_shutdown(&application.renderer)
	renderer.logger_close()
	renderer.vulkan_logger_close()

	free_all(context.temp_allocator)
}
