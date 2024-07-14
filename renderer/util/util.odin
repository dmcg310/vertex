package util

import "core:strings"

to_cstring :: proc(s: string) -> cstring {
	return strings.clone_to_cstring(s)
}
