package renderer

import "core:fmt"
import "core:mem"
import "core:os"
import "core:path/filepath"
import "core:strings"

import stb "vendor:stb/image"
import vk "vendor:vulkan"

import "../util"

TextureImage :: struct {
	image: VMAImage,
}

TextureImageView :: struct {
	view: vk.ImageView,
}

TextureSampler :: struct {
	sampler: vk.Sampler,
}

texture_image_create :: proc(
	device: vk.Device,
	command_pool: vk.CommandPool,
	graphics_queue: vk.Queue,
	vma_allocator: VMAAllocator,
) -> TextureImage {
	if TEXTURE_PATH == "" {
		return {}
	}

	texture_image := TextureImage{}

	vertex_path, get_ok, error := util.get_vertex_base_path()
	if !get_ok {
		log(error, "ERROR")
		return {}
	}

	full_path := strings.join(
		{vertex_path, TEXTURE_PATH},
		"/",
		context.temp_allocator,
	)

	texture_width, texture_height, texture_channels: i32
	pixels := stb.load(
		util.to_cstring(full_path),
		&texture_width,
		&texture_height,
		&texture_channels,
		4, // RGBA
	)
	if pixels == nil {
		log(fmt.tprintf("Failed to load texture: %v", full_path), "ERROR")
		return {}
	}
	defer stb.image_free(pixels)

	image_size := vk.DeviceSize(texture_width * texture_height * 4)

	staging_buffer, staging_buffer_allocation := vma_buffer_create(
		vma_allocator,
		image_size,
		{.TRANSFER_SRC},
		.AUTO,
		{.HOST_ACCESS_SEQUENTIAL_WRITE},
	)
	defer vma_buffer_destroy(
		vma_allocator,
		staging_buffer,
		staging_buffer_allocation,
	)

	mapped_data := vma_map_memory(vma_allocator, staging_buffer_allocation)
	mem.copy(mapped_data, pixels, int(image_size))
	vma_unmap_memory(vma_allocator, staging_buffer_allocation)

	texture_image.image = vma_image_create(
		vma_allocator,
		u32(texture_width),
		u32(texture_height),
		.R8G8B8A8_SRGB,
		.OPTIMAL,
		{.TRANSFER_DST, .SAMPLED},
		.AUTO,
	)

	transition_image_layout(
		texture_image.image.image,
		.R8G8B8A8_SRGB,
		.UNDEFINED,
		.TRANSFER_DST_OPTIMAL,
		device,
		command_pool,
		graphics_queue,
	)
	copy_buffer_to_image(
		staging_buffer,
		texture_image.image.image,
		u32(texture_width),
		u32(texture_height),
		device,
		command_pool,
		graphics_queue,
	)
	transition_image_layout(
		texture_image.image.image,
		.R8G8B8A8_SRGB,
		.TRANSFER_DST_OPTIMAL,
		.SHADER_READ_ONLY_OPTIMAL,
		device,
		command_pool,
		graphics_queue,
	)

	log(fmt.tprintf("Loaded texture: %v", full_path))

	return texture_image
}

texture_image_destroy :: proc(
	vma_allocator: VMAAllocator,
	texture_image: TextureImage,
) {
	vma_image_destroy(vma_allocator, texture_image.image)
}

texture_image_view_create :: proc(
	device: vk.Device,
	texture_image: TextureImage,
) -> TextureImageView {
	if texture_image == {} {
		return {}
	}

	texture_image_view := TextureImageView{}

	texture_image_view.view = image_view_create(
		device,
		texture_image.image.image,
		.R8G8B8A8_SRGB,
		{.COLOR},
	)

	return texture_image_view
}

texture_image_view_destroy :: proc(
	device: vk.Device,
	texture_image_view: TextureImageView,
) {
	vk.DestroyImageView(device, texture_image_view.view, nil)
}

texture_sampler_create :: proc(device: Device) -> TextureSampler {
	texture_sampler := TextureSampler{}

	properties := vk.PhysicalDeviceProperties{}
	vk.GetPhysicalDeviceProperties(device.physical_device, &properties)

	sampler_info := vk.SamplerCreateInfo {
		sType                   = .SAMPLER_CREATE_INFO,
		magFilter               = .LINEAR,
		minFilter               = .LINEAR,
		addressModeU            = .REPEAT,
		addressModeV            = .REPEAT,
		addressModeW            = .REPEAT,
		anisotropyEnable        = true,
		maxAnisotropy           = properties.limits.maxSamplerAnisotropy,
		borderColor             = .INT_OPAQUE_BLACK,
		unnormalizedCoordinates = false,
		compareEnable           = false,
		compareOp               = .ALWAYS,
		mipmapMode              = .LINEAR,
		mipLodBias              = 0,
		minLod                  = 0,
		maxLod                  = 0,
	}

	if result := vk.CreateSampler(
		device.logical_device,
		&sampler_info,
		nil,
		&texture_sampler.sampler,
	); result != .SUCCESS {
		log_fatal_with_vk_result("Failed to create texture sampler", result)
	}

	log("Vulkan texture sampler created")

	return texture_sampler
}

texture_sampler_destroy :: proc(
	device: vk.Device,
	texture_sampler: TextureSampler,
) {
	vk.DestroySampler(device, texture_sampler.sampler, nil)

	log("Vulkan texture sampler destroyed")
}

image_view_create :: proc(
	device: vk.Device,
	image: vk.Image,
	format: vk.Format,
	aspect_flags: vk.ImageAspectFlags,
) -> vk.ImageView {
	view_info := vk.ImageViewCreateInfo {
		sType = .IMAGE_VIEW_CREATE_INFO,
		image = image,
		viewType = .D2,
		format = format,
		subresourceRange = {
			aspectMask = aspect_flags,
			baseMipLevel = 0,
			levelCount = 1,
			baseArrayLayer = 0,
			layerCount = 1,
		},
	}

	image_view: vk.ImageView
	if result := vk.CreateImageView(device, &view_info, nil, &image_view);
	   result != .SUCCESS {
		log_fatal_with_vk_result("Failed to create image view", result)
	}

	return image_view
}

texture_entries_filter :: proc(entries: []string) -> []string {
	res := make([dynamic]string, 0, len(entries), context.temp_allocator)
	for entry in entries {
		base := filepath.base(entry)

		if os.is_dir(base) {
			continue
		}

		if strings.has_suffix(base, ".png") ||
		   strings.has_suffix(base, ".jpg") ||
		   strings.has_suffix(base, ".tga") ||
		   strings.has_suffix(base, ".dds") ||
		   strings.has_suffix(base, ".bmp") ||
		   strings.has_suffix(base, ".jpeg") {
			if base != "" && base != " " {
				append(&res, base)
			}
		}
	}

	return res[:]
}

@(private = "file")
transition_image_layout :: proc(
	image: vk.Image,
	format: vk.Format,
	old_layout: vk.ImageLayout,
	new_layout: vk.ImageLayout,
	device: vk.Device,
	command_pool: vk.CommandPool,
	graphics_queue: vk.Queue,
) {
	command_buffer := command_begin_single_time(device, command_pool)

	barrier := vk.ImageMemoryBarrier {
		sType = .IMAGE_MEMORY_BARRIER,
		oldLayout = old_layout,
		newLayout = new_layout,
		srcQueueFamilyIndex = vk.QUEUE_FAMILY_IGNORED,
		dstQueueFamilyIndex = vk.QUEUE_FAMILY_IGNORED,
		image = image,
		subresourceRange = {
			aspectMask = {.COLOR},
			baseMipLevel = 0,
			levelCount = 1,
			baseArrayLayer = 0,
			layerCount = 1,
		},
	}

	source_stage, destination_stage: vk.PipelineStageFlags

	if old_layout == .UNDEFINED && new_layout == .TRANSFER_DST_OPTIMAL {
		barrier.srcAccessMask = nil
		barrier.dstAccessMask = {.TRANSFER_WRITE}

		source_stage = {.TOP_OF_PIPE}
		destination_stage = {.TRANSFER}
	} else if old_layout == .TRANSFER_DST_OPTIMAL &&
	   new_layout == .SHADER_READ_ONLY_OPTIMAL {
		barrier.srcAccessMask = {.TRANSFER_WRITE}
		barrier.dstAccessMask = {.SHADER_READ}

		source_stage = {.TRANSFER}
		destination_stage = {.FRAGMENT_SHADER}
	} else {
		log_fatal("Unsupported layout transition")
	}

	vk.CmdPipelineBarrier(
		command_buffer,
		source_stage,
		destination_stage,
		nil,
		0,
		nil,
		0,
		nil,
		1,
		&barrier,
	)

	command_end_single_time(
		device,
		command_pool,
		graphics_queue,
		&command_buffer,
	)
}

@(private = "file")
copy_buffer_to_image :: proc(
	buffer: vk.Buffer,
	image: vk.Image,
	width, height: u32,
	device: vk.Device,
	command_pool: vk.CommandPool,
	graphics_queue: vk.Queue,
) {
	command_buffer := command_begin_single_time(device, command_pool)

	region := vk.BufferImageCopy {
		bufferOffset = 0,
		bufferRowLength = 0,
		bufferImageHeight = 0,
		imageSubresource = {
			aspectMask = {.COLOR},
			mipLevel = 0,
			baseArrayLayer = 0,
			layerCount = 1,
		},
		imageOffset = {0, 0, 0},
		imageExtent = {width, height, 1},
	}

	vk.CmdCopyBufferToImage(
		command_buffer,
		buffer,
		image,
		.TRANSFER_DST_OPTIMAL,
		1,
		&region,
	)

	command_end_single_time(
		device,
		command_pool,
		graphics_queue,
		&command_buffer,
	)
}
