package renderer

import "core:time"

RendererTime :: struct {
	last_frame_time:              f64,
	delta_time:                   f64,
	fps:                          f32,
	fps_update_interval:          f64,
	frames_since_last_fps_update: int,
	time_since_last_fps_update:   f64,
	total_time:                   f64,
	refresh_rate:                 i32,
}

renderer_time_init :: proc(refresh_rate: i32) -> RendererTime {
	return RendererTime {
		last_frame_time = get_current_time(),
		delta_time = 0,
		fps = 0,
		fps_update_interval = 0.5,
		frames_since_last_fps_update = 0,
		time_since_last_fps_update = 0,
		total_time = 0,
		refresh_rate = refresh_rate,
	}
}

renderer_time_update :: proc(renderer_time: ^RendererTime) {
	current_time := get_current_time()
	renderer_time.delta_time = current_time - renderer_time.last_frame_time
	renderer_time.last_frame_time = current_time

	renderer_time.total_time += renderer_time.delta_time

	renderer_time.frames_since_last_fps_update += 1
	renderer_time.time_since_last_fps_update += renderer_time.delta_time

	if renderer_time.time_since_last_fps_update >=
	   renderer_time.fps_update_interval {
		renderer_time.fps =
			f32(renderer_time.frames_since_last_fps_update) /
			f32(renderer_time.time_since_last_fps_update)
		renderer_time.frames_since_last_fps_update = 0
		renderer_time.time_since_last_fps_update = 0
	}
}

@(private = "file")
get_current_time :: proc() -> f64 {
	return f64(time.now()._nsec) / 1e9
}
