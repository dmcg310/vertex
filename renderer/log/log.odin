package log

import "core:fmt"
import "core:os"
import "core:path/filepath"
import "core:time"
import vk "vendor:vulkan"

Logger :: struct {
	file: os.Handle,
}

@(private)
logger: Logger
@(private)
vulkan_logger: Logger
@(private)
vulkan_log_count: int
@(private)
vulkan_error_count: int
@(private)
vulkan_warning_count: int

init_logger :: proc() -> (err: os.Errno) {
	logs_dir := "logs"

	if os.make_directory(logs_dir) != 0 {
		if !os.exists(logs_dir) {
			return os.EPERM
		}
	}

	log_file_name: string
	when ODIN_DEBUG {
		log_file_name = "debug_log.txt"
	} else {
		log_file_name = "release_log.txt"
	}

	log_file_path := filepath.join({logs_dir, log_file_name})

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

init_vulkan_logger :: proc() -> (err: os.Errno) {
	logs_dir := "logs"
	if os.make_directory(logs_dir) != 0 {
		if !os.exists(logs_dir) {
			return os.EPERM
		}
	}

	vulkan_log_file := filepath.join({logs_dir, "vulkan_validation.log"})
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

	when ODIN_DEBUG {
		os.write_string(logger.file, formatted_message)
		fmt.print(formatted_message)
	} else {
		if level == "ERROR" || level == "CRITICAL" {
			os.write_string(logger.file, formatted_message)
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
	fmt.eprint(formatted_message)

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

close_logger :: proc() {
	if logger.file != 0 {
		log("Logging terminated")
		os.close(logger.file)
	}
}

close_vulkan_logger :: proc() {
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
			fmt.tprintf("\n--- Summary ---\n%s\n", summary),
		)

		os.close(vulkan_logger.file)
	}
}

@(private)
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
