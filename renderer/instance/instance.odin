package instance

import "../util"
import "../window"
import "core:fmt"
import "vendor:glfw"
import vk "vendor:vulkan"

Instance :: struct {
	instance:                  vk.Instance,
	debug_messenger:           vk.DebugUtilsMessengerEXT,
	validation_layers_enabled: bool,
}

create_instance :: proc(enable_validation_layers: bool) -> Instance {
	instance := Instance{}
	instance.validation_layers_enabled = enable_validation_layers

	glfw_extensions := glfw.GetRequiredInstanceExtensions()

	app_info := vk.ApplicationInfo{}
	app_info.sType = vk.StructureType.APPLICATION_INFO
	app_info.pNext = nil
	app_info.pApplicationName = util.to_cstring("Vertex")
	app_info.applicationVersion = vk.MAKE_VERSION(1, 0, 0)
	app_info.pEngineName = util.to_cstring("No Engine")
	app_info.engineVersion = vk.MAKE_VERSION(1, 0, 0)
	app_info.apiVersion = vk.API_VERSION_1_3

	create_info := vk.InstanceCreateInfo{}
	create_info.sType = vk.StructureType.INSTANCE_CREATE_INFO
	create_info.pNext = nil
	create_info.flags = nil
	create_info.pApplicationInfo = &app_info
	create_info.enabledLayerCount = 0
	create_info.ppEnabledLayerNames = nil
	create_info.enabledExtensionCount = u32(len(glfw_extensions))
	create_info.ppEnabledExtensionNames = raw_data(glfw_extensions)

	if result := vk.CreateInstance(&create_info, nil, &instance.instance);
	   result != vk.Result.SUCCESS {
		panic("Failed to create Vulkan instance:")
	}

	if enable_validation_layers {
	}

	return instance
}

destroy_instance :: proc(instance: Instance) {
}
