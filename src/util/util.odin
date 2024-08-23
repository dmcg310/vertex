package util

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
