package instance

import "../log"
import "../util"
import "base:runtime"
import "vendor:glfw"
import vk "vendor:vulkan"

Instance :: struct {
	instance:                  vk.Instance,
	debug_messenger:           vk.DebugUtilsMessengerEXT,
	validation_layers_enabled: bool,
}

VALIDATION_LAYERS := [dynamic]string{"VK_LAYER_KHRONOS_validation"}

when ODIN_OS == .Windows {
	vulkan_debug_callback :: proc "stdcall" (
		severity: vk.DebugUtilsMessageSeverityFlagsEXT,
		type: vk.DebugUtilsMessageTypeFlagsEXT,
		callback_data: ^vk.DebugUtilsMessengerCallbackDataEXT,
		user_data: rawptr,
	) -> b32 {
		context = runtime.default_context()
		message := util.from_cstring(callback_data.pMessage)

		log.log_vulkan(message, severity)

		return false
	}
} else {
	vulkan_debug_callback :: proc "cdecl" (
		severity: vk.DebugUtilsMessageSeverityFlagsEXT,
		type: vk.DebugUtilsMessageTypeFlagsEXT,
		callback_data: ^vk.DebugUtilsMessengerCallbackDataEXT,
		user_data: rawptr,
	) -> b32 {
		context = runtime.default_context()
		message := util.from_cstring(callback_data.pMessage)

		log.log_vulkan(message, severity)

		return false
	}
}

create_instance :: proc(enable_validation_layers: bool) -> Instance {
	vk.load_proc_addresses((rawptr)(glfw.GetInstanceProcAddress))

	instance := Instance {
		validation_layers_enabled = enable_validation_layers,
	}

	if enable_validation_layers && !check_validation_layer_support() {
		log.log_fatal("Validation layers requested, but not available")
	}

	app_info := vk.ApplicationInfo {
		sType              = .APPLICATION_INFO,
		pNext              = nil,
		pApplicationName   = util.to_cstring("Vertex"),
		applicationVersion = vk.MAKE_VERSION(1, 0, 0),
		pEngineName        = util.to_cstring("No Engine"),
		engineVersion      = vk.MAKE_VERSION(1, 0, 0),
		apiVersion         = vk.API_VERSION_1_3,
	}

	extensions := get_required_extensions(instance)

	create_info := vk.InstanceCreateInfo {
		sType                   = .INSTANCE_CREATE_INFO,
		pNext                   = nil,
		flags                   = nil,
		pApplicationInfo        = &app_info,
		enabledExtensionCount   = u32(len(extensions)),
		ppEnabledExtensionNames = raw_data(extensions),
	}

	debug_create_info := vk.DebugUtilsMessengerCreateInfoEXT{}

	if enable_validation_layers {
		create_info.enabledLayerCount = u32(len(VALIDATION_LAYERS))

		cstring_arr_validation_layers :=
			util.dynamic_array_of_strings_to_cstrings(VALIDATION_LAYERS)

		create_info.ppEnabledLayerNames = raw_data(
			cstring_arr_validation_layers,
		)

		populate_debug_messenger_create_info(&debug_create_info)

		create_info.pNext = &debug_create_info
	} else {
		create_info.enabledLayerCount = 0
		create_info.ppEnabledLayerNames = nil
	}

	if result := vk.CreateInstance(&create_info, nil, &instance.instance);
	   result != .SUCCESS {
		log.log_fatal_with_vk_result(
			"Failed to create Vulkan instance",
			result,
		)
	}

	vk.load_proc_addresses(instance.instance)

	if enable_validation_layers {
		setup_debug_messenger(&instance)
	}

	log.log("Vulkan instance created")

	return instance
}

destroy_instance :: proc(instance: Instance) {
	if instance.validation_layers_enabled {
		destroy_debug_utils_messenger_ext(
			instance.instance,
			instance.debug_messenger,
			nil,
		)
	}

	if instance.instance != nil {
		vk.DestroyInstance(instance.instance, nil)
	}

	log.log("Vulkan instance destroyed")
}

@(private)
check_validation_layer_support :: proc() -> bool {
	layer_count: u32 = 0
	vk.EnumerateInstanceLayerProperties(&layer_count, nil)

	available_layers := make(
		[]vk.LayerProperties,
		layer_count,
		context.temp_allocator,
	)

	vk.EnumerateInstanceLayerProperties(
		&layer_count,
		raw_data(available_layers),
	)

	for layer_name in VALIDATION_LAYERS {
		layer_found := false

		for layer_properties in available_layers {
			temp := layer_properties.layerName
			comparison := util.string_from_bytes(temp[:])

			if layer_name == comparison {
				layer_found = true
				break
			}
		}

		if !layer_found {
			return false
		}
	}

	return true
}

@(private)
get_required_extensions :: proc(instance: Instance) -> []cstring {
	glfw_extensions := glfw.GetRequiredInstanceExtensions()
	glfw_extension_count := len(glfw_extensions)

	new_extensions := make(
		[]cstring,
		glfw_extension_count + 1,
		context.temp_allocator,
	)
	copy(new_extensions, glfw_extensions)

	if instance.validation_layers_enabled {
		new_extensions[glfw_extension_count] =
			vk.EXT_DEBUG_UTILS_EXTENSION_NAME
	}

	return new_extensions
}

@(private)
setup_debug_messenger :: proc(instance: ^Instance) {
	if !instance.validation_layers_enabled {
		return
	}

	create_info := vk.DebugUtilsMessengerCreateInfoEXT{}
	populate_debug_messenger_create_info(&create_info)

	if result := create_debug_utils_messenger_ext(
		instance.instance,
		&create_info,
		nil,
		&instance.debug_messenger,
	); result != .SUCCESS {
		log.log_fatal_with_vk_result(
			"Failed to set up debug messenger",
			result,
		)
	}
}

@(private)
create_debug_utils_messenger_ext :: proc(
	instance: vk.Instance,
	create_info: ^vk.DebugUtilsMessengerCreateInfoEXT,
	allocator: ^vk.AllocationCallbacks,
	messenger: ^vk.DebugUtilsMessengerEXT,
) -> vk.Result {
	PFN_vkCreateDebugUtilsMessengerEXT :: proc(
		instance: vk.Instance,
		create_info: ^vk.DebugUtilsMessengerCreateInfoEXT,
		allocator: ^vk.AllocationCallbacks,
		debug_messenger: ^vk.DebugUtilsMessengerEXT,
	) -> vk.Result

	func := cast(PFN_vkCreateDebugUtilsMessengerEXT)(vk.GetInstanceProcAddr(
			instance,
			"vkCreateDebugUtilsMessengerEXT",
		))

	if func != nil {
		return func(instance, create_info, allocator, messenger)
	} else {
		return .ERROR_EXTENSION_NOT_PRESENT
	}
}

@(private)
populate_debug_messenger_create_info :: proc(
	create_info: ^vk.DebugUtilsMessengerCreateInfoEXT,
) {
	create_info.sType = .DEBUG_UTILS_MESSENGER_CREATE_INFO_EXT
	create_info.messageSeverity = {.WARNING, .ERROR}
	create_info.messageType = {.VALIDATION, .PERFORMANCE}
	create_info.pfnUserCallback = vulkan_debug_callback
	create_info.pUserData = nil
}

@(private)
destroy_debug_utils_messenger_ext :: proc(
	instance: vk.Instance,
	debug_messenger: vk.DebugUtilsMessengerEXT,
	allocator: ^vk.AllocationCallbacks,
) {
	PFN_vkDestroyDebugUtilsMessengerEXT :: proc(
		instance: vk.Instance,
		debug_messenger: vk.DebugUtilsMessengerEXT,
		allocator: ^vk.AllocationCallbacks,
	)

	func := cast(PFN_vkDestroyDebugUtilsMessengerEXT)(vk.GetInstanceProcAddr(
			instance,
			"vkDestroyDebugUtilsMessengerEXT",
		))

	if func != nil {
		func(instance, debug_messenger, allocator)
	}
}
