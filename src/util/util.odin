package util

import "../log"
import "core:fmt"
import "core:os"
import "core:strings"

// Ensure caller frees the data
to_cstring :: proc(s: string) -> cstring {
	return strings.clone_to_cstring(s)
}

// Ensure caller frees the data
from_cstring :: proc(s: cstring) -> string {
	return strings.clone_from_cstring(s)
}

// Ensure caller frees the data
string_from_bytes :: proc(data: []u8) -> string {
	return strings.trim(strings.clone_from_bytes(data), "\x00")
}

// Ensure caller frees the data
dynamic_array_of_strings_to_cstrings :: proc(
	data: [dynamic]string,
) -> []cstring {
	result := make([]cstring, len(data))

	for str, i in data {
		result[i] = to_cstring(str)
	}

	return result
}

// Ensure caller frees the data
read_file :: proc(path: string) -> ([]byte, bool) {
	data, ok := os.read_entire_file(path)
	if !ok {
		log.log(fmt.aprintf("Failed to read file %s", path), "WARNING")
		return nil, false
	}

	return data, true
}
