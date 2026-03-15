package yaml

import "core:c"
import "core:mem"
import "core:math"
import "core:reflect"
import "core:strconv"
import "core:strings"
import "base:runtime"

// ---------------------------------------------------------------------------
// Error Types
// ---------------------------------------------------------------------------

Unmarshal_Data_Error :: enum {
	Invalid_Data,
	Invalid_Parameter,
	Non_Pointer_Parameter,
}

Unsupported_Type_Error :: struct {
	id: typeid,
}

Yaml_Parse_Error :: struct {
	problem: string,
	line:    int,
	column:  int,
}

Scalar_Conversion_Error :: struct {
	value:       string,
	target_type: typeid,
}

Unmarshal_Error :: union {
	Unmarshal_Data_Error,
	Unsupported_Type_Error,
	Yaml_Parse_Error,
	Scalar_Conversion_Error,
	runtime.Allocator_Error,
}

// ---------------------------------------------------------------------------
// Custom Unmarshaler Types & Registry
// ---------------------------------------------------------------------------

// Context passed to custom unmarshalers (node operation helpers)
Unmarshal_Context :: struct {
	doc:       ^document_t,
	node:      ^node_t,
	allocator: mem.Allocator,
}

// Custom unmarshaler procedure type
// v: target any value (points directly to data, not a pointer)
User_Unmarshaler :: #type proc(ctx: Unmarshal_Context, v: any) -> Unmarshal_Error

// Registry errors
Register_User_Unmarshaler_Error :: enum {
	None,
	No_User_Unmarshaler,
	Unmarshaler_Previously_Found,
}

@(private)
_user_unmarshalers: ^map[typeid]User_Unmarshaler

// Initialize the custom unmarshaler registry (same pattern as core:encoding/json)
set_user_unmarshalers :: proc(m: ^map[typeid]User_Unmarshaler) {
	_user_unmarshalers = m
}

// Register a custom unmarshaler for a specific type
register_user_unmarshaler :: proc(id: typeid, unmarshaler: User_Unmarshaler) -> Register_User_Unmarshaler_Error {
	if _user_unmarshalers == nil {
		return .No_User_Unmarshaler
	}
	if id in _user_unmarshalers^ {
		return .Unmarshaler_Previously_Found
	}
	_user_unmarshalers^[id] = unmarshaler
	return .None
}

// ---------------------------------------------------------------------------
// Unmarshal_Context Helpers
// ---------------------------------------------------------------------------

// Decode ctx.node into target using built-in reflection rules,
// BYPASSING any custom unmarshaler registered for target's type.
// Use this inside a custom unmarshaler to delegate to the standard decode
// without re-triggering itself (avoids infinite recursion).
unmarshal_ctx_decode :: proc(ctx: Unmarshal_Context, target: any) -> Unmarshal_Error {
	return unmarshal_node_internal(ctx.doc, ctx.node, target, ctx.allocator)
}

// Decode a specific node into target using full unmarshal dispatch,
// INCLUDING custom unmarshalers. WARNING: if target's type is the same as
// the calling custom unmarshaler's type, this causes infinite recursion.
// Use unmarshal_ctx_decode instead when decoding the same type.
unmarshal_ctx_decode_node :: proc(ctx: Unmarshal_Context, node: ^node_t, target: any) -> Unmarshal_Error {
	return unmarshal_node(ctx.doc, node, target, ctx.allocator)
}

// Get the node type
unmarshal_ctx_node_type :: proc(ctx: Unmarshal_Context) -> node_type_t {
	if ctx.node == nil { return .NO_NODE }
	return ctx.node.type
}

// Get the scalar value as a string
unmarshal_ctx_node_value :: proc(ctx: Unmarshal_Context) -> string {
	return node_to_string(ctx.node)
}

// Get mapping pairs
unmarshal_ctx_mapping_pairs :: proc(ctx: Unmarshal_Context) -> []node_pair_t {
	if ctx.node == nil || ctx.node.type != .MAPPING_NODE { return nil }
	start, count := node_mapping_pairs(ctx.node)
	if count <= 0 { return nil }
	return start[:count]
}

// Get sequence items
unmarshal_ctx_sequence_items :: proc(ctx: Unmarshal_Context) -> []node_item_t {
	if ctx.node == nil || ctx.node.type != .SEQUENCE_NODE { return nil }
	start, count := node_sequence_items(ctx.node)
	if count <= 0 { return nil }
	return start[:count]
}

// Get a node by its ID
unmarshal_ctx_get_node :: proc(ctx: Unmarshal_Context, id: node_item_t) -> ^node_t {
	return document_get_node(ctx.doc, id)
}

// ---------------------------------------------------------------------------
// Public API
// ---------------------------------------------------------------------------

unmarshal :: proc(data: []byte, ptr: ^$T, allocator := context.allocator) -> Unmarshal_Error {
	return unmarshal_any(data, ptr, allocator)
}

unmarshal_string :: proc(data: string, ptr: ^$T, allocator := context.allocator) -> Unmarshal_Error {
	return unmarshal_any(transmute([]byte)data, ptr, allocator)
}

unmarshal_any :: proc(data: []byte, v: any, allocator := context.allocator) -> Unmarshal_Error {
	v := v
	if v == nil || v.id == nil {
		return .Invalid_Parameter
	}
	v = reflect.any_base(v)
	ti := type_info_of(v.id)
	if !reflect.is_pointer(ti) || ti.id == rawptr {
		return .Non_Pointer_Parameter
	}

	// Dereference the pointer to get the target
	target := any{(^rawptr)(v.data)^, ti.variant.(reflect.Type_Info_Pointer).elem.id}
	if target.data == nil {
		return .Invalid_Parameter
	}

	// Initialize parser
	parser: parser_t
	if parser_initialize(&parser) == 0 {
		return Yaml_Parse_Error{problem = "failed to initialize parser"}
	}
	defer parser_delete(&parser)

	parser_set_input_string(&parser, raw_data(data), len(data))

	// Load document
	doc: document_t
	if parser_load(&parser, &doc) == 0 {
		problem_str := string(parser.problem) if parser.problem != nil else "unknown parse error"
		return Yaml_Parse_Error{
			problem = problem_str,
			line    = int(parser.problem_mark.line) + 1,
			column  = int(parser.problem_mark.column) + 1,
		}
	}
	defer document_delete(&doc)

	root := document_get_root_node(&doc)
	if root == nil {
		// Empty document — leave target as zero value
		return nil
	}

	return unmarshal_node(&doc, root, target, allocator)
}

// ---------------------------------------------------------------------------
// Private: Recursive Node Dispatcher
// ---------------------------------------------------------------------------

@(private)
unmarshal_node :: proc(doc: ^document_t, node: ^node_t, v: any, allocator: mem.Allocator) -> Unmarshal_Error {
	v := v

	// Custom unmarshaler check (highest priority)
	if _user_unmarshalers != nil {
		if unmarshaler, found := _user_unmarshalers^[v.id]; found && unmarshaler != nil {
			ctx := Unmarshal_Context{doc = doc, node = node, allocator = allocator}
			return unmarshaler(ctx, v)
		}
	}

	return unmarshal_node_internal(doc, node, v, allocator)
}

// Internal node dispatcher (without custom unmarshaler check, used by unmarshal_ctx_decode)
@(private)
unmarshal_node_internal :: proc(doc: ^document_t, node: ^node_t, v: any, allocator: mem.Allocator) -> Unmarshal_Error {
	v := v
	ti := reflect.type_info_base(type_info_of(v.id))

	// Handle pointer types: allocate and recurse
	if p, ok := ti.variant.(reflect.Type_Info_Pointer); ok {
		if is_null_node(node) {
			(^rawptr)(v.data)^ = nil
			return nil
		}
		elem_ti := p.elem
		ptr, err := mem.alloc(elem_ti.size, elem_ti.align, allocator)
		if err != nil {
			return err
		}
		(^rawptr)(v.data)^ = ptr
		return unmarshal_node(doc, node, any{ptr, elem_ti.id}, allocator)
	}

	// Handle union types (including Maybe(T))
	if u, ok := ti.variant.(reflect.Type_Info_Union); ok {
		if is_null_node(node) {
			mem.zero(v.data, ti.size)
			return nil
		}
		if len(u.variants) == 1 {
			// Single variant union (e.g. Maybe(T))
			variant := u.variants[0]
			if !reflect.is_pointer_internally(variant) {
				tag := any{rawptr(uintptr(v.data) + u.tag_offset), u.tag_type.id}
				assign_int(tag, 1)
			}
			return unmarshal_node(doc, node, any{v.data, variant.id}, allocator)
		}
		// Multi-variant: try each
		for variant, i in u.variants {
			variant_any := any{v.data, variant.id}
			if err := unmarshal_node(doc, node, variant_any, allocator); err == nil {
				raw_tag := i
				if !u.no_nil { raw_tag += 1 }
				tag := any{rawptr(uintptr(v.data) + u.tag_offset), u.tag_type.id}
				assign_int(tag, raw_tag)
				return nil
			}
		}
		return Unsupported_Type_Error{v.id}
	}

	// Null handling for non-pointer/union types
	if is_null_node(node) {
		mem.zero(v.data, ti.size)
		return nil
	}

	// Dispatch by node type
	switch node.type {
	case .SCALAR_NODE:
		return unmarshal_scalar(doc, node, v, allocator)
	case .MAPPING_NODE:
		return unmarshal_mapping(doc, node, v, allocator)
	case .SEQUENCE_NODE:
		return unmarshal_sequence(doc, node, v, allocator)
	case .NO_NODE:
		return nil
	}

	return nil
}

// ---------------------------------------------------------------------------
// Private: Scalar Value Conversion
// ---------------------------------------------------------------------------

@(private)
unmarshal_scalar :: proc(doc: ^document_t, node: ^node_t, v: any, allocator: mem.Allocator) -> Unmarshal_Error {
	scalar := node_to_string(node)
	v := v
	ti := reflect.type_info_base(type_info_of(v.id))

	#partial switch t in ti.variant {
	case reflect.Type_Info_String:
		if v.id == cstring {
			cs, err := strings.clone_to_cstring(scalar, allocator)
			if err != nil { return err }
			(^cstring)(v.data)^ = cs
		} else {
			s, err := strings.clone(scalar, allocator)
			if err != nil { return err }
			(^string)(v.data)^ = s
		}
		return nil

	case reflect.Type_Info_Boolean:
		b, ok := parse_yaml_bool(scalar)
		if !ok {
			return Scalar_Conversion_Error{value = scalar, target_type = v.id}
		}
		assign_bool(v, b)
		return nil

	case reflect.Type_Info_Integer:
		// Try integer parse
		if i, ok := parse_yaml_int(scalar); ok {
			if assign_int(v, i) { return nil }
		}
		return Scalar_Conversion_Error{value = scalar, target_type = v.id}

	case reflect.Type_Info_Float:
		if f, ok := parse_yaml_float(scalar); ok {
			if assign_float(v, f) { return nil }
		}
		return Scalar_Conversion_Error{value = scalar, target_type = v.id}

	case reflect.Type_Info_Enum:
		// Try matching enum name (exact)
		for name, i in t.names {
			if name == scalar {
				assign_int(v, t.values[i])
				return nil
			}
		}
		// Try matching enum name (case-insensitive)
		scalar_lower := strings.to_lower(scalar, context.temp_allocator)
		for name, i in t.names {
			name_lower := strings.to_lower(name, context.temp_allocator)
			if name_lower == scalar_lower {
				assign_int(v, t.values[i])
				return nil
			}
		}
		// Try parsing as integer
		if ival, ok := strconv.parse_i128(scalar); ok {
			assign_int(v, ival)
			return nil
		}
		return Scalar_Conversion_Error{value = scalar, target_type = v.id}
	}

	return Unsupported_Type_Error{v.id}
}

// ---------------------------------------------------------------------------
// Private: Mapping Processing
// ---------------------------------------------------------------------------

@(private)
unmarshal_mapping :: proc(doc: ^document_t, node: ^node_t, v: any, allocator: mem.Allocator) -> Unmarshal_Error {
	v := v
	ti := reflect.type_info_base(type_info_of(v.id))

	pairs_start, count := node_mapping_pairs(node)

	#partial switch t in ti.variant {
	case reflect.Type_Info_Struct:
		if .raw_union in t.flags {
			return Unsupported_Type_Error{v.id}
		}

		fields := reflect.struct_fields_zipped(ti.id)

		for i := 0; i < count; i += 1 {
			pair := pairs_start[i]
			key_node := document_get_node(doc, pair.key)
			val_node := document_get_node(doc, pair.value)
			if key_node == nil || val_node == nil { continue }

			key_str := node_to_string(key_node)
			field_idx := find_struct_field(fields, key_str)
			if field_idx < 0 { continue }

			field := fields[field_idx]
			field_ptr := rawptr(uintptr(v.data) + field.offset)
			field_any := any{field_ptr, field.type.id}
			if err := unmarshal_node(doc, val_node, field_any, allocator); err != nil {
				return err
			}
		}
		return nil

	case reflect.Type_Info_Map:
		if !reflect.is_string(t.key) {
			return Unsupported_Type_Error{v.id}
		}

		raw_map := (^mem.Raw_Map)(v.data)
		if raw_map.allocator.procedure == nil {
			raw_map.allocator = allocator
		}

		elem_backing, alloc_err := mem.alloc_bytes(t.value.size, t.value.align, allocator)
		if alloc_err != nil { return alloc_err }
		defer mem.free_bytes(elem_backing, allocator)

		for i := 0; i < count; i += 1 {
			pair := pairs_start[i]
			key_node := document_get_node(doc, pair.key)
			val_node := document_get_node(doc, pair.value)
			if key_node == nil || val_node == nil { continue }

			key_str := node_to_string(key_node)
			key_cloned, clone_err := strings.clone(key_str, allocator)
			if clone_err != nil { return clone_err }

			mem.zero_slice(elem_backing)
			map_val := any{raw_data(elem_backing), t.value.id}
			if err := unmarshal_node(doc, val_node, map_val, allocator); err != nil {
				delete(key_cloned, allocator)
				return err
			}

			key_ptr: rawptr = &key_cloned
			key_cstr: cstring
			if reflect.is_cstring(t.key) {
				key_cstr = cstring(raw_data(key_cloned))
				key_ptr = &key_cstr
			}

			set_ptr := runtime.__dynamic_map_set_without_hash(raw_map, t.map_info, key_ptr, map_val.data)
			if set_ptr == nil {
				delete(key_cloned, allocator)
			}
		}
		return nil
	}

	return Unsupported_Type_Error{v.id}
}

// ---------------------------------------------------------------------------
// Private: Sequence Processing
// ---------------------------------------------------------------------------

@(private)
unmarshal_sequence :: proc(doc: ^document_t, node: ^node_t, v: any, allocator: mem.Allocator) -> Unmarshal_Error {
	v := v
	ti := reflect.type_info_base(type_info_of(v.id))

	items_start, count := node_sequence_items(node)

	#partial switch t in ti.variant {
	case reflect.Type_Info_Slice:
		raw := (^mem.Raw_Slice)(v.data)
		data, err := mem.alloc_bytes(t.elem.size * count, t.elem.align, allocator)
		if err != nil { return err }
		raw.data = raw_data(data)
		raw.len = count

		for i := 0; i < count; i += 1 {
			item_idx := items_start[i]
			item_node := document_get_node(doc, item_idx)
			if item_node == nil { continue }
			elem_ptr := rawptr(uintptr(raw.data) + uintptr(i * t.elem.size))
			elem := any{elem_ptr, t.elem.id}
			if uerr := unmarshal_node(doc, item_node, elem, allocator); uerr != nil {
				return uerr
			}
		}
		return nil

	case reflect.Type_Info_Dynamic_Array:
		raw := (^mem.Raw_Dynamic_Array)(v.data)
		data, err := mem.alloc_bytes(t.elem.size * count, t.elem.align, allocator)
		if err != nil { return err }
		raw.data = raw_data(data)
		raw.len = count
		raw.cap = count
		raw.allocator = allocator

		for i := 0; i < count; i += 1 {
			item_idx := items_start[i]
			item_node := document_get_node(doc, item_idx)
			if item_node == nil { continue }
			elem_ptr := rawptr(uintptr(raw.data) + uintptr(i * t.elem.size))
			elem := any{elem_ptr, t.elem.id}
			if uerr := unmarshal_node(doc, item_node, elem, allocator); uerr != nil {
				return uerr
			}
		}
		return nil

	case reflect.Type_Info_Array:
		n := min(count, t.count)
		for i := 0; i < n; i += 1 {
			item_idx := items_start[i]
			item_node := document_get_node(doc, item_idx)
			if item_node == nil { continue }
			elem_ptr := rawptr(uintptr(v.data) + uintptr(i * t.elem_size))
			elem := any{elem_ptr, t.elem.id}
			if uerr := unmarshal_node(doc, item_node, elem, allocator); uerr != nil {
				return uerr
			}
		}
		return nil

	case reflect.Type_Info_Struct:
		// Positional mapping: sequence elements → struct fields by order
		if .raw_union in t.flags {
			return Unsupported_Type_Error{v.id}
		}
		fields := reflect.struct_fields_zipped(ti.id)
		n := min(count, len(fields))
		for i := 0; i < n; i += 1 {
			item_idx := items_start[i]
			item_node := document_get_node(doc, item_idx)
			if item_node == nil { continue }

			field := fields[i]
			// Skip fields tagged with yaml:"-"
			tag_value := reflect.struct_tag_get(field.tag, "yaml")
			if tag_value == "-" { continue }

			field_ptr := rawptr(uintptr(v.data) + field.offset)
			field_any := any{field_ptr, field.type.id}
			if uerr := unmarshal_node(doc, item_node, field_any, allocator); uerr != nil {
				return uerr
			}
		}
		return nil
	}

	return Unsupported_Type_Error{v.id}
}

// ---------------------------------------------------------------------------
// Private: Struct Field Search
// ---------------------------------------------------------------------------

@(private)
find_struct_field :: proc(fields: #soa[]reflect.Struct_Field, key: string) -> int {
	// Pass 1: match by yaml tag
	for field, idx in fields {
		tag_value := reflect.struct_tag_get(field.tag, "yaml")
		if tag_value != "" {
			yaml_name, _ := yaml_name_from_tag_value(tag_value)
			if yaml_name == "-" { continue }
			if yaml_name == key { return idx }
		}
	}
	// Pass 2: match by field name (only for fields without yaml tag)
	for field, idx in fields {
		tag_value := reflect.struct_tag_get(field.tag, "yaml")
		if tag_value == "" && field.name == key {
			return idx
		}
	}
	return -1
}

// ---------------------------------------------------------------------------
// Private: Helpers
// ---------------------------------------------------------------------------

@(private)
node_mapping_pairs :: proc(node: ^node_t) -> (start: [^]node_pair_t, count: int) {
	s := node.data.mapping.pairs.start
	t := node.data.mapping.pairs.top
	n := int(uintptr(t) - uintptr(s)) / size_of(node_pair_t)
	return s, max(n, 0)
}

@(private)
node_sequence_items :: proc(node: ^node_t) -> (start: [^]node_item_t, count: int) {
	s := node.data.sequence.items.start
	t := node.data.sequence.items.top
	n := int(uintptr(t) - uintptr(s)) / size_of(node_item_t)
	return s, max(n, 0)
}

@(private)
node_to_string :: proc(node: ^node_t) -> string {
	if node == nil { return "" }
	if node.type != .SCALAR_NODE { return "" }
	value := node.data.scalar.value
	length := node.data.scalar.length
	if value == nil || length == 0 { return "" }
	return string(value[:length])
}

@(private)
is_null_node :: proc(node: ^node_t) -> bool {
	if node == nil { return true }
	if node.type != .SCALAR_NODE { return false }
	s := node_to_string(node)
	return s == "" || s == "null" || s == "Null" || s == "NULL" || s == "~"
}

@(private)
yaml_name_from_tag_value :: proc(value: string) -> (name: string, extra: string) {
	idx := strings.index_byte(value, ',')
	if idx < 0 {
		return value, ""
	}
	return value[:idx], value[idx+1:]
}

@(private)
parse_yaml_bool :: proc(s: string) -> (val: bool, ok: bool) {
	switch s {
	case "true", "True", "TRUE", "yes", "Yes", "YES", "on", "On", "ON":
		return true, true
	case "false", "False", "FALSE", "no", "No", "NO", "off", "Off", "OFF":
		return false, true
	}
	return false, false
}

@(private)
parse_yaml_int :: proc(s: string) -> (val: i128, ok: bool) {
	if len(s) == 0 { return 0, false }

	str := s
	negative := false
	if str[0] == '-' {
		negative = true
		str = str[1:]
	} else if str[0] == '+' {
		str = str[1:]
	}

	result: i128
	parse_ok: bool

	if len(str) > 2 && str[0] == '0' {
		switch str[1] {
		case 'x', 'X':
			result, parse_ok = strconv.parse_i128_of_base(str[2:], 16)
		case 'o', 'O':
			result, parse_ok = strconv.parse_i128_of_base(str[2:], 8)
		case 'b', 'B':
			result, parse_ok = strconv.parse_i128_of_base(str[2:], 2)
		case:
			// Octal without prefix (YAML 1.1 style: 0777)
			if is_all_octal(str) {
				result, parse_ok = strconv.parse_i128_of_base(str, 8)
			} else {
				result, parse_ok = strconv.parse_i128(str)
			}
		}
	} else {
		result, parse_ok = strconv.parse_i128(str)
	}

	if !parse_ok { return 0, false }
	if negative { result = -result }
	return result, true
}

@(private)
is_all_octal :: proc(s: string) -> bool {
	for ch in s {
		if ch < '0' || ch > '7' { return false }
	}
	return len(s) > 0
}

@(private)
parse_yaml_float :: proc(s: string) -> (val: f64, ok: bool) {
	switch s {
	case ".inf", ".Inf", ".INF", "+.inf", "+.Inf", "+.INF":
		return math.inf_f64(1), true
	case "-.inf", "-.Inf", "-.INF":
		return math.inf_f64(-1), true
	case ".nan", ".NaN", ".NAN":
		return math.nan_f64(), true
	}
	return strconv.parse_f64(s)
}

@(private)
assign_bool :: proc(val: any, b: bool) -> bool {
	v := reflect.any_core(val)
	switch &dst in v {
	case bool: dst = bool(b)
	case b8:   dst = b8(b)
	case b16:  dst = b16(b)
	case b32:  dst = b32(b)
	case b64:  dst = b64(b)
	case: return false
	}
	return true
}

@(private)
assign_int :: proc(val: any, i: $T) -> bool {
	v := reflect.any_core(val)
	switch &dst in v {
	case i8:      dst = i8(i)
	case i16:     dst = i16(i)
	case i16le:   dst = i16le(i)
	case i16be:   dst = i16be(i)
	case i32:     dst = i32(i)
	case i32le:   dst = i32le(i)
	case i32be:   dst = i32be(i)
	case i64:     dst = i64(i)
	case i64le:   dst = i64le(i)
	case i64be:   dst = i64be(i)
	case i128:    dst = i128(i)
	case i128le:  dst = i128le(i)
	case i128be:  dst = i128be(i)
	case u8:      dst = u8(i)
	case u16:     dst = u16(i)
	case u16le:   dst = u16le(i)
	case u16be:   dst = u16be(i)
	case u32:     dst = u32(i)
	case u32le:   dst = u32le(i)
	case u32be:   dst = u32be(i)
	case u64:     dst = u64(i)
	case u64le:   dst = u64le(i)
	case u64be:   dst = u64be(i)
	case u128:    dst = u128(i)
	case u128le:  dst = u128le(i)
	case u128be:  dst = u128be(i)
	case int:     dst = int(i)
	case uint:    dst = uint(i)
	case uintptr: dst = uintptr(i)
	case: return false
	}
	return true
}

@(private)
assign_float :: proc(val: any, f: $T) -> bool {
	v := reflect.any_core(val)
	switch &dst in v {
	case f16:   dst = f16(f)
	case f16le: dst = f16le(f)
	case f16be: dst = f16be(f)
	case f32:   dst = f32(f)
	case f32le: dst = f32le(f)
	case f32be: dst = f32be(f)
	case f64:   dst = f64(f)
	case f64le: dst = f64le(f)
	case f64be: dst = f64be(f)
	case: return false
	}
	return true
}
