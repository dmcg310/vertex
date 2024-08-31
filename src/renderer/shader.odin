package renderer

import "core:fmt"
import "core:os"
import "core:path/filepath"
import "core:strings"

import vk "vendor:vulkan"

import "../util"

Shaders :: struct {
	vertex_shader:   []byte,
	fragment_shader: []byte,
}

shaders_read :: proc(paths: []string) -> (Shaders, bool) {
	shaders := Shaders{}

	for path, i in paths {
		data, ok := read_file(path)
		if !ok {
			return shaders, false
		}

		if i == 0 {
			shaders.vertex_shader = data
		} else {
			shaders.fragment_shader = data
		}

		str := fmt.aprintf("Loaded shader: %s", path)
		defer delete(str)

		log(str)
	}

	return shaders, true
}

shader_module_create :: proc(
	code: []byte,
	device: vk.Device,
) -> vk.ShaderModule {
	create_info := vk.ShaderModuleCreateInfo {
		sType    = .SHADER_MODULE_CREATE_INFO,
		codeSize = len(code),
		pCode    = cast(^u32)raw_data(code),
	}

	shader_module: vk.ShaderModule
	if result := vk.CreateShaderModule(
		device,
		&create_info,
		nil,
		&shader_module,
	); result != .SUCCESS {
		log_fatal_with_vk_result("Failed to create shader module", result)
	}

	return shader_module
}

shader_stage_create :: proc(
	stage: vk.ShaderStageFlags,
	module: vk.ShaderModule,
) -> vk.PipelineShaderStageCreateInfo {
	return vk.PipelineShaderStageCreateInfo {
		sType = .PIPELINE_SHADER_STAGE_CREATE_INFO,
		stage = stage,
		module = module,
		pName = "main",
	}
}

read_file :: proc(path: string) -> ([]byte, bool) {
	vertex_path, get_ok, error := util.get_vertex_base_path()
	if !get_ok {
		log(error, "ERROR")
		return nil, false
	}

	full_path := strings.join({vertex_path, path}, "/", context.temp_allocator)

	data, read_ok := os.read_entire_file(full_path, context.temp_allocator)
	if !read_ok {
		msg := fmt.aprintf("Failed to read file %s", full_path)
		defer delete(msg)

		log(msg, "WARNING")

		return nil, false
	}

	return data, true
}

shader_entries_filter :: proc(entries: []string) -> []string {
	res := make([dynamic]string, 0, len(entries), context.temp_allocator)
	for entry in entries {
		base := filepath.base(entry)

		if os.is_dir(base) {
			continue
		}

		if strings.has_suffix(base, ".vert") ||
		   strings.has_suffix(base, ".frag") {
			if base != "" && base != " " {
				append(&res, base)
			}
		}
	}

	return res[:]
}
