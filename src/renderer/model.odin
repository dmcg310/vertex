package renderer

import "core:fmt"
import "core:strconv"
import "core:strings"

Attrib :: struct {
	vertices:   [dynamic]f32,
	normals:    [dynamic]f32,
	tex_coords: [dynamic]f32,
}

Shape :: struct {
	name:    string,
	indices: [dynamic]Index,
}

Index :: struct {
	vertex_index:    int,
	normal_index:    int,
	tex_coord_index: int,
}

Model :: struct {
	vertices: [dynamic]Vertex,
	indices:  [dynamic]u32,
}

model_load :: proc(path: string) -> (Attrib, []Shape) {
	data, read_ok := read_file(path)
	if !read_ok {
		log(fmt.aprintf("Failed to read model: %v", path), "ERROR")
		return {}, nil
	}

	attrib := Attrib {
		vertices   = make([dynamic]f32, context.temp_allocator),
		normals    = make([dynamic]f32, context.temp_allocator),
		tex_coords = make([dynamic]f32, context.temp_allocator),
	}

	shapes := make([dynamic]Shape, context.temp_allocator)
	current_shape := Shape {
		indices = make([dynamic]Index, 0, 1024, context.temp_allocator),
	}

	lines := strings.split(string(data), "\n")
	defer delete(lines)

	for line in lines {
		parts := strings.split(strings.trim_space(line), " ")
		if len(parts) == 0 do continue
		defer delete(parts)

		switch parts[0] {
		case "v":
			if len(parts) == 4 {
				for i in 1 ..= 3 {
					value := strconv.parse_f32(parts[i]) or_else 0
					append(&attrib.vertices, value)
				}
			}
		case "vn":
			if len(parts) == 4 {
				for i in 1 ..= 3 {
					value := strconv.parse_f32(parts[i]) or_else 0
					append(&attrib.normals, value)
				}
			}
		case "vt":
			if len(parts) == 3 {
				for i in 1 ..= 2 {
					value := strconv.parse_f32(parts[i]) or_else 0
					append(&attrib.tex_coords, value)
				}
			}
		case "f":
			if len(parts) >= 4 {
				for i in 1 ..< len(parts) {
					indices := strings.split(parts[i], "/")
					defer delete(indices)

					index := Index {
						vertex_index    = strconv.parse_int(
							indices[0],
						) or_else 0,
						tex_coord_index = strconv.parse_int(
							indices[1],
						) or_else 0 if len(indices) > 1 else 0,
						normal_index    = strconv.parse_int(
							indices[2],
						) or_else 0 if len(indices) > 2 else 0,
					}
					append(&current_shape.indices, index)
				}

			}
		case "o", "g":
			if len(current_shape.indices) > 0 {
				append(&shapes, current_shape)
				current_shape = Shape {
					indices = make(
						[dynamic]Index,
						1024,
						context.temp_allocator,
					),
				}
			}

			if len(parts) > 1 {
				current_shape.name = strings.join(
					parts[1:],
					" ",
					context.temp_allocator,
				)
			}
		}
	}

	if len(current_shape.indices) > 0 {
		append(&shapes, current_shape)
	}

	log(fmt.tprintf("Loaded model: %v", path))

	return attrib, shapes[:]
}

model_create :: proc(attrib: Attrib, shapes: []Shape) -> Model {
	model := Model {
		vertices = make([dynamic]Vertex, context.temp_allocator),
		indices  = make([dynamic]u32, context.temp_allocator),
	}

	for shape in shapes {
		for index in shape.indices {
			pos_x := attrib.vertices[3 * (index.vertex_index - 1)]
			pos_y := attrib.vertices[3 * (index.vertex_index - 1) + 1]
			pos_z := attrib.vertices[3 * (index.vertex_index - 1) + 2]

			tex_coord_x: f32
			if index.tex_coord_index > 0 {
				tex_coord_x =
					attrib.tex_coords[2 * (index.tex_coord_index - 1)]
			} else {
				tex_coord_x = 0
			}

			tex_coord_y: f32
			if index.tex_coord_index > 0 {
				tex_coord_y =
					1.0 -
					(attrib.tex_coords[2 * (index.tex_coord_index - 1) + 1])
			} else {
				tex_coord_y = 0
			}

			vertex := Vertex {
				pos      = {pos_x, pos_y, pos_z},
				texCoord = {tex_coord_x, tex_coord_y},
				color    = {1, 1, 1},
			}

			append(&model.vertices, vertex)
			append(&model.indices, u32(len(model.vertices) - 1))
		}
	}

	return model
}
