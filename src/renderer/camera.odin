package renderer

import "core:math/linalg"

Camera :: struct {
	position:       Vec3,
	target:         Vec3,
	up:             Vec3,
	min_zoom:       f32,
	max_zoom:       f32,
	orbit_distance: f32,
	yaw:            f32,
	pitch:          f32,
}

camera_init :: proc() -> Camera {
	return Camera {
		position = Vec3{5, 5, 5},
		target = Vec3{0, 0, 0},
		up = Vec3{0, 0, 1},
		min_zoom = 1.0,
		max_zoom = 5.0,
		orbit_distance = 5.0,
		yaw = 45.0,
		pitch = 45.0,
	}
}

camera_position_update :: proc(camera: ^Camera) {
	// Convert from spherical to Cartesian coordinates
	pitch_rad := linalg.to_radians(camera.pitch)
	yaw_rad := linalg.to_radians(camera.yaw)

	camera.position = {
		camera.orbit_distance * linalg.cos(pitch_rad) * linalg.cos(yaw_rad),
		camera.orbit_distance * linalg.cos(pitch_rad) * linalg.sin(yaw_rad),
		camera.orbit_distance * linalg.sin(pitch_rad),
	}
}
