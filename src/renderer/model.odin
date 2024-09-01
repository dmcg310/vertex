package renderer

import "core:fmt"
import "core:os"
import "core:path/filepath"
import "core:strconv"
import "core:strings"
import "core:thread"

Model :: struct {
	vertices: [dynamic]Vertex,
	indices:  [dynamic]u32,
}

@(private = "file")
Attrib :: struct {
	vertices:   [dynamic]f32,
	normals:    [dynamic]f32,
	tex_coords: [dynamic]f32,
}

@(private = "file")
Shape :: struct {
	name:    string,
	indices: [dynamic]Index,
}

@(private = "file")
Index :: struct {
	vertex_index:    int,
	normal_index:    int,
	tex_coord_index: int,
}

@(private = "file")
ChunkResult :: struct {
	attrib: Attrib,
	shapes: [dynamic]Shape,
}

@(private = "file")
ChunkData :: struct {
	chunk:  []string,
	result: ^ChunkResult,
}

@(private = "file")
NUM_THREADS :: 4

model_load :: proc() -> (Attrib, []Shape) {
	if MODEL_PATH == "" {
		return {}, nil
	}

	data, read_ok := read_file(MODEL_PATH)
	if !read_ok {
		log(fmt.tprintf("Failed to read model: %v", MODEL_PATH), "ERROR")
		return {}, nil
	}

	log(fmt.tprintf("Loading model: %v", MODEL_PATH))

	lines := strings.split(string(data), "\n")
	defer delete(lines)

	chunk_size := len(lines) / NUM_THREADS
	chunks := make([]ChunkData, NUM_THREADS, context.temp_allocator)
	results := make([]ChunkResult, NUM_THREADS, context.temp_allocator)

	for i in 0 ..< NUM_THREADS {
		start := i * chunk_size
		end := min((i + 1) * chunk_size, len(lines))

		if i == NUM_THREADS - 1 {
			end = len(lines)
		}

		chunks[i] = ChunkData {
			chunk  = lines[start:end],
			result = &results[i],
		}
	}

	pool: thread.Pool
	thread.pool_init(&pool, context.allocator, thread_count = NUM_THREADS)
	defer thread.pool_destroy(&pool)

	process_chunk :: proc(task: thread.Task) {
		chunk_data := cast(^ChunkData)task.data
		chunk_data.result^ = process_chunk_data(chunk_data.chunk)
	}

	for i in 0 ..< NUM_THREADS {
		thread.pool_add_task(
			&pool,
			context.allocator,
			procedure = process_chunk,
			data = &chunks[i],
			user_index = i,
		)
	}

	thread.pool_start(&pool)
	thread.pool_finish(&pool)

	final_attrib := Attrib {
		vertices   = make([dynamic]f32, context.temp_allocator),
		normals    = make([dynamic]f32, context.temp_allocator),
		tex_coords = make([dynamic]f32, context.temp_allocator),
	}
	final_shapes := make([dynamic]Shape, context.temp_allocator)

	for result in results {
		append(&final_attrib.vertices, ..result.attrib.vertices[:])
		append(&final_attrib.normals, ..result.attrib.normals[:])
		append(&final_attrib.tex_coords, ..result.attrib.tex_coords[:])
		append(&final_shapes, ..result.shapes[:])

		delete(result.attrib.vertices)
		delete(result.attrib.normals)
		delete(result.attrib.tex_coords)
		delete(result.shapes)
	}

	log(fmt.tprintf("Loaded model: %v", MODEL_PATH))

	return final_attrib, final_shapes[:]
}

model_create :: proc(attrib: Attrib, shapes: []Shape) -> Model {
	model := Model {
		vertices = make([dynamic]Vertex, context.temp_allocator),
		indices  = make([dynamic]u32, context.temp_allocator),
	}

	unique_vertices := make(map[Vertex]u32, 1024, context.temp_allocator)

	for shape in shapes {
		defer delete(shape.indices)

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

			if existing_index, ok := unique_vertices[vertex]; ok {
				append(&model.indices, existing_index)
			} else {
				new_index := u32(len(model.vertices))
				unique_vertices[vertex] = new_index

				append(&model.vertices, vertex)
				append(&model.indices, new_index)
			}
		}
	}

	return model
}

model_entries_filter :: proc(entries: []string) -> []string {
	res := make([dynamic]string, 0, len(entries), context.temp_allocator)
	for entry in entries {
		base := filepath.base(entry)

		if os.is_dir(base) {
			continue
		}

		if !strings.has_suffix(entry, ".obj") {
			continue
		}

		if base == "" || base == " " {
			continue
		}

		append(&res, filepath.base(entry))
	}

	return res[:]
}

@(private = "file")
process_chunk_data :: proc(chunk: []string) -> ChunkResult {
	result := ChunkResult {
		attrib = Attrib {
			vertices = make([dynamic]f32),
			normals = make([dynamic]f32),
			tex_coords = make([dynamic]f32),
		},
		shapes = make([dynamic]Shape),
	}

	current_shape := Shape {
		indices = make([dynamic]Index, 0, 1024),
	}

	for line in chunk {
		parts := strings.split(strings.trim_space(line), " ")
		if len(parts) == 0 do continue
		defer delete(parts)

		switch parts[0] {
		case "v":
			if len(parts) == 4 {
				for i in 1 ..= 3 {
					value := strconv.parse_f32(parts[i]) or_else 0
					append(&result.attrib.vertices, value)
				}
			}
		case "vn":
			if len(parts) == 4 {
				for i in 1 ..= 3 {
					value := strconv.parse_f32(parts[i]) or_else 0
					append(&result.attrib.normals, value)
				}
			}
		case "vt":
			if len(parts) == 3 {
				for i in 1 ..= 2 {
					value := strconv.parse_f32(parts[i]) or_else 0
					append(&result.attrib.tex_coords, value)
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
				append(&result.shapes, current_shape)
				current_shape = Shape {
					indices = make([dynamic]Index, 1024),
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
		append(&result.shapes, current_shape)
	} else {
		delete(current_shape.indices)
	}

	return result
}
