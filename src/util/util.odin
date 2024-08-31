package util

import "core:fmt"
import "core:os"
import "core:strings"

to_cstring :: proc(s: string) -> cstring {
	return strings.clone_to_cstring(s, context.temp_allocator)
}

from_cstring :: proc(s: cstring) -> string {
	return strings.clone_from_cstring(s, context.temp_allocator)
}

string_from_bytes :: proc(data: []u8) -> string {
	return strings.trim(
		strings.clone_from_bytes(data, context.temp_allocator),
		"\x00",
	)
}

dynamic_array_of_strings_to_cstrings :: proc(
	data: [dynamic]string,
) -> []cstring {
	result := make([]cstring, len(data), context.temp_allocator)

	for str, i in data {
		result[i] = to_cstring(str)
	}

	return result
}

list_entries_in_dir :: proc(
	dir: string,
) -> (
	entries: []string,
	ok: bool,
	error: string,
) {
	handle, open_err := os.open(dir)
	if open_err != 0 {
		return nil, false, fmt.tprintf("Failed to read: %v", dir)
	}
	defer os.close(handle)

	fi, read_err := os.read_dir(handle, 100, context.temp_allocator)
	if read_err != 0 {
		return nil, false, fmt.tprintf("Failed to read: %v", dir)
	}

	res := make([dynamic]string, len(entries), context.temp_allocator)
	for entry in fi {
		append(&res, entry.fullpath)
	}

	return res[:], true, ""
}
