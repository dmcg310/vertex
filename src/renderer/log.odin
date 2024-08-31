package renderer

import "core:fmt"
import "core:os"
import "core:path/filepath"
import "core:strings"
import "core:time"

import vk "vendor:vulkan"

import "../util"

COLOR_RESET :: "\x1b[0m"
COLOR_RED :: "\x1b[31m"
COLOR_GREY :: "\x1b[90m"
COLOR_YELLOW :: "\x1b[33m"
COLOR_BLUE :: "\x1b[34m"

@(private = "file")
logger: Logger

@(private = "file")
vulkan_logger: Logger

@(private = "file")
vulkan_log_count: int

@(private = "file")
vulkan_error_count: int

@(private = "file")
vulkan_warning_count: int

Logger :: struct {
	file: os.Handle,
}

logger_init :: proc() -> (err: os.Errno) {
	full_path, ok := get_full_log_path()
	if !ok {
		return nil
	}

	if os.make_directory(full_path) != 0 {
		if !os.exists(full_path) {
			return path_not_found_error()
		}
	}

	log_file_name: string
	when ODIN_DEBUG {
		log_file_name = "debug_log.txt"
	} else {
		log_file_name = "release_log.txt"
	}

	log_file_path := filepath.join(
		{full_path, log_file_name},
		context.temp_allocator,
	)

	logger.file, err = os.open(
		log_file_path,
		os.O_WRONLY | os.O_CREATE | os.O_TRUNC,
		0o644,
	)
	if err != 0 {
		fmt.eprintln("Failed to open log file:", err)
		return
	}

	log("Logging initialized")

	return
}

vulkan_logger_init :: proc() -> (err: os.Errno) {
	full_path, ok := get_full_log_path()
	if !ok {
		return nil
	}

	if os.make_directory(full_path) != 0 {
		if !os.exists(full_path) {
			return path_not_found_error()
		}
	}

	vulkan_log_file := filepath.join(
		{full_path, "vulkan_validation.log"},
		context.temp_allocator,
	)
	vulkan_logger.file, err = os.open(
		vulkan_log_file,
		os.O_WRONLY | os.O_CREATE | os.O_TRUNC,
		0o644,
	)
	if err != 0 {
		fmt.eprintln("Failed to open Vulkan log file:", err)
		return
	}

	log("Vulkan validation logging initialized")

	return
}

log :: proc(message: string, level: string = "INFO") {
	timestamp := time.now()
	formatted_message := fmt.tprintf(
		"[%v] [%s] %s\n",
		timestamp,
		level,
		message,
	)

	os.write_string(logger.file, formatted_message)

	when ODIN_DEBUG {
		color := COLOR_RESET
		switch level {
		case "INFO":
			color = COLOR_GREY
		case "WARNING":
			color = COLOR_YELLOW
		case "ERROR", "CRITICAL":
			color = COLOR_RED
		case "DEBUG":
			color = COLOR_BLUE
		}

		colored_message := fmt.tprintf(
			"%s%s%s",
			color,
			formatted_message,
			COLOR_RESET,
		)

		fmt.print(colored_message)
	} else {
		if level == "ERROR" || level == "CRITICAL" {
			fmt.eprint(formatted_message)
		}
	}
}

log_vulkan :: proc(
	message: string,
	severity: vk.DebugUtilsMessageSeverityFlagsEXT,
) {
	timestamp := time.now()
	severity_str := get_log_level(severity)
	formatted_message := fmt.tprintf(
		"[%v] [%s] %s\n",
		timestamp,
		severity_str,
		message,
	)

	os.write_string(vulkan_logger.file, formatted_message)

	vulkan_log_count += 1

	if .ERROR in severity {
		vulkan_error_count += 1
	} else if .WARNING in severity {
		vulkan_warning_count += 1
	}
}

log_fatal :: proc(message: string, loc := #caller_location) {
	timestamp := time.now()
	formatted_message := fmt.tprintf(
		"[%v] [FATAL] %v:%d:%d %s\n",
		timestamp,
		loc.file_path,
		loc.line,
		loc.column,
		message,
	)

	os.write_string(logger.file, formatted_message)

	colored_message := fmt.tprintf(
		"%s%s%s",
		COLOR_RED,
		formatted_message,
		COLOR_RESET,
	)
	fmt.eprint(colored_message)

	os.exit(1)
}

log_fatal_with_vk_result :: proc(
	message: string,
	result: vk.Result,
	loc := #caller_location,
) {
	formatted_message := fmt.tprintf("%s. Vulkan result: %v", message, result)
	log_fatal(formatted_message, loc)
}

logger_close :: proc() {
	if logger.file != 0 {
		log("Logging terminated")
		os.close(logger.file)
	}
}

vulkan_logger_close :: proc() {
	if vulkan_logger.file != 0 {
		summary := fmt.tprintf(
			"Vulkan validation logging terminated. Total logs: %d, Errors: %d, Warnings: %d",
			vulkan_log_count,
			vulkan_error_count,
			vulkan_warning_count,
		)
		log(summary)

		os.write_string(
			vulkan_logger.file,
			fmt.tprintf("\n=== Summary ===\n%s\n", summary),
		)

		os.close(vulkan_logger.file)
	}
}

@(private = "file")
get_log_level :: proc(
	severity: vk.DebugUtilsMessageSeverityFlagsEXT,
) -> string {
	if .ERROR in severity {
		return "ERROR"
	} else if .WARNING in severity {
		return "WARNING"
	} else if .INFO in severity {
		return "INFO"
	} else {
		return "DEBUG"
	}
}

@(private = "file")
path_not_found_error :: proc() -> os.Errno {
	when ODIN_OS == .Windows {
		return os.ERROR_PATH_NOT_FOUND
	} else {
		return os.ENONET
	}
}

@(private = "file")
get_full_log_path :: proc() -> (string, bool) {
	logs_path := "logs"

	vertex_path, get_ok, error := util.get_vertex_base_path()
	if !get_ok {
		fmt.eprintln(error)
		return "", false
	}

	full_path := strings.join(
		{vertex_path, logs_path},
		"/",
		context.temp_allocator,
	)

	return full_path, true
}
