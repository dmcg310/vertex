package shader

import "../util"
import "core:fmt"
import vk "vendor:vulkan"

Shaders :: struct {
	vertex_shader:   []byte,
	fragment_shader: []byte,
}

read_shaders :: proc(paths: []string) -> (Shaders, bool) {
	shaders := Shaders{}

	for path, i in paths {
		data, ok := util.read_file(path)
		if !ok {
			return shaders, false
		}

		if i == 0 {
			fmt.printfln("%s loaded", path)
			shaders.vertex_shader = data
		} else {
			fmt.printfln("%s loaded", path)
			shaders.fragment_shader = data
		}
	}

	return shaders, true
}

create_shader_module :: proc(
	code: []byte,
	device: vk.Device,
) -> vk.ShaderModule {
	create_info := vk.ShaderModuleCreateInfo{}
	create_info.sType = vk.StructureType.SHADER_MODULE_CREATE_INFO
	create_info.codeSize = len(code)
	create_info.pCode = transmute(^u32)raw_data(code)

	shader_module: vk.ShaderModule
	if (vk.CreateShaderModule(device, &create_info, nil, &shader_module) !=
		   vk.Result.SUCCESS) {
		panic("Failed to create shader module")
	}

	return shader_module
}

create_shader_stage :: proc(
	stage: vk.ShaderStageFlags,
	module: vk.ShaderModule,
) -> vk.PipelineShaderStageCreateInfo {
	stage_create_info := vk.PipelineShaderStageCreateInfo{}
	stage_create_info.sType =
		vk.StructureType.PIPELINE_SHADER_STAGE_CREATE_INFO
	stage_create_info.stage = stage
	stage_create_info.module = module
	stage_create_info.pName = "main"

	return stage_create_info
}
