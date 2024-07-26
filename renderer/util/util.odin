package util

import "core:fmt"
import "core:os"
import "core:strings"

to_cstring :: proc(s: string) -> cstring {
	return strings.clone_to_cstring(s)
}

from_cstring :: proc(s: cstring) -> string {
	return strings.clone_from_cstring(s)
}

string_from_bytes :: proc(data: []u8) -> string {
	return strings.trim(strings.clone_from_bytes(data), "\x00")
}

dynamic_array_of_strings_to_cstrings :: proc(
	data: [dynamic]string,
) -> []cstring {
	result := make([]cstring, len(data))

	for str, i in data {
		result[i] = to_cstring(str)
	}

	return result
}

read_file :: proc(path: string) -> ([]byte, bool) {
	data, ok := os.read_entire_file(path)
	if !ok {
		fmt.eprintfln("Failed to read file: %s", path)
		return nil, false
	}

	return data, true
}
