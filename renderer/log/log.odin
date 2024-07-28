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
