package main

import "core:fmt"
import "core:os"
import "core:strconv"
import "core:strings"
import yaml ".."

// ---------------------------------------------------------------------------
// Custom Unmarshalers
// ---------------------------------------------------------------------------

register_inst_unmarshalers :: proc(m: ^map[typeid]yaml.User_Unmarshaler) {
	yaml.set_user_unmarshalers(m)
	yaml.register_user_unmarshaler(Inst_Drum_Entry, unmarshal_drum_entry)
	yaml.register_user_unmarshaler(Inst_CC, unmarshal_cc)
	yaml.register_user_unmarshaler(Inst_CC14, unmarshal_cc14)
	yaml.register_user_unmarshaler(Inst_NRPN, unmarshal_nrpn)
	yaml.register_user_unmarshaler([dynamic]Inst_Enum_Entry, unmarshal_enum_entries)
	yaml.register_user_unmarshaler([dynamic]Inst_Sysex_Element, unmarshal_sysex_body)
}

// drum entry: single-element map { name: note_number } or explicit mapping
unmarshal_drum_entry :: proc(ctx: yaml.Unmarshal_Context, v: any) -> yaml.Unmarshal_Error {
	if yaml.unmarshal_ctx_node_type(ctx) != .MAPPING_NODE { return nil }
	pairs := yaml.unmarshal_ctx_mapping_pairs(ctx)
	entry := (^Inst_Drum_Entry)(v.data)

	// Check if it's a shorthand form (single key that is NOT "name")
	if len(pairs) == 1 {
		key_node := yaml.unmarshal_ctx_get_node(ctx, pairs[0].key)
		val_node := yaml.unmarshal_ctx_get_node(ctx, pairs[0].value)
		if key_node == nil || val_node == nil { return nil }
		key_str := node_scalar(key_node)
		if key_str != "name" {
			entry.name = strings.clone(key_str, ctx.allocator) or_return
			yaml.unmarshal_ctx_decode_node(ctx, val_node, any{&entry.note_number, typeid_of(int)})
			return nil
		}
	}
	// Explicit form: delegate to standard decode
	return yaml.unmarshal_ctx_decode(ctx, v)
}

// CC: shorthand { name: cc_number } or explicit mapping
unmarshal_cc :: proc(ctx: yaml.Unmarshal_Context, v: any) -> yaml.Unmarshal_Error {
	if yaml.unmarshal_ctx_node_type(ctx) != .MAPPING_NODE { return nil }
	pairs := yaml.unmarshal_ctx_mapping_pairs(ctx)
	cc := (^Inst_CC)(v.data)

	// Check for shorthand: single key that is NOT a known field name
	if len(pairs) == 1 {
		key_node := yaml.unmarshal_ctx_get_node(ctx, pairs[0].key)
		val_node := yaml.unmarshal_ctx_get_node(ctx, pairs[0].value)
		if key_node == nil || val_node == nil { return nil }
		key_str := node_scalar(key_node)
		if !is_cc_field(key_str) {
			cc.name = strings.clone(key_str, ctx.allocator) or_return
			yaml.unmarshal_ctx_decode_node(ctx, val_node, any{&cc.cc, typeid_of(int)})
			return nil
		}
	}
	// Explicit form: delegate to standard decode
	return yaml.unmarshal_ctx_decode(ctx, v)
}

// CC14: shorthand { name: { msb: N, lsb: N } } or explicit mapping
unmarshal_cc14 :: proc(ctx: yaml.Unmarshal_Context, v: any) -> yaml.Unmarshal_Error {
	if yaml.unmarshal_ctx_node_type(ctx) != .MAPPING_NODE { return nil }
	pairs := yaml.unmarshal_ctx_mapping_pairs(ctx)
	cc14 := (^Inst_CC14)(v.data)

	// Check for shorthand: single key that is NOT a known field name
	if len(pairs) == 1 {
		key_node := yaml.unmarshal_ctx_get_node(ctx, pairs[0].key)
		val_node := yaml.unmarshal_ctx_get_node(ctx, pairs[0].value)
		if key_node == nil || val_node == nil { return nil }
		key_str := node_scalar(key_node)
		if !is_cc14_field(key_str) {
			// Shorthand: { filter_cutoff: { msb: 19, lsb: 51 } }
			cc14.name = strings.clone(key_str, ctx.allocator) or_return
			// Decode the sub-mapping {msb, lsb, ...} into cc14, bypassing
			// the custom unmarshaler to avoid infinite recursion
			sub_ctx := yaml.Unmarshal_Context{doc = ctx.doc, node = val_node, allocator = ctx.allocator}
			yaml.unmarshal_ctx_decode(sub_ctx, any{cc14, typeid_of(Inst_CC14)})
			return nil
		}
	}
	return yaml.unmarshal_ctx_decode(ctx, v)
}

// NRPN: handle lsb field which can be int or "note"
unmarshal_nrpn :: proc(ctx: yaml.Unmarshal_Context, v: any) -> yaml.Unmarshal_Error {
	if yaml.unmarshal_ctx_node_type(ctx) != .MAPPING_NODE { return nil }
	nrpn := (^Inst_NRPN)(v.data)

	// First, standard decode for all tagged fields
	if err := yaml.unmarshal_ctx_decode(ctx, v); err != nil {
		return err
	}

	// Then manually handle 'lsb' field
	pairs := yaml.unmarshal_ctx_mapping_pairs(ctx)
	for pair in pairs {
		key_node := yaml.unmarshal_ctx_get_node(ctx, pair.key)
		if key_node == nil { continue }
		if node_scalar(key_node) != "lsb" { continue }

		val_node := yaml.unmarshal_ctx_get_node(ctx, pair.value)
		if val_node == nil { continue }

		lsb_str := node_scalar(val_node)
		if lsb_str == "note" {
			nrpn.lsb_is_note = true
			nrpn.lsb = 0
		} else {
			if lsb_val, ok := parse_yaml_int(lsb_str); ok {
				nrpn.lsb = lsb_val
			}
		}
		break
	}
	return nil
}

// enum entries: YAML mapping { label: value_or_range, ... } → [dynamic]Inst_Enum_Entry
unmarshal_enum_entries :: proc(ctx: yaml.Unmarshal_Context, v: any) -> yaml.Unmarshal_Error {
	if yaml.unmarshal_ctx_node_type(ctx) != .MAPPING_NODE { return nil }
	entries := (^[dynamic]Inst_Enum_Entry)(v.data)
	pairs := yaml.unmarshal_ctx_mapping_pairs(ctx)

	for pair in pairs {
		key_node := yaml.unmarshal_ctx_get_node(ctx, pair.key)
		val_node := yaml.unmarshal_ctx_get_node(ctx, pair.value)
		if key_node == nil || val_node == nil { continue }

		entry: Inst_Enum_Entry
		entry.label = strings.clone(node_scalar(key_node), ctx.allocator) or_return

		if val_node.type == .SCALAR_NODE {
			// Single value: { label: 42 }
			if ival, ok := parse_yaml_int(node_scalar(val_node)); ok {
				entry.min_value = ival
				entry.max_value = ival
			}
		} else if val_node.type == .SEQUENCE_NODE {
			// Range: { label: [min, max] }
			r: Inst_Range
			yaml.unmarshal_ctx_decode_node(ctx, val_node, any{&r, typeid_of(Inst_Range)})
			entry.min_value = r.min
			entry.max_value = r.max
		}

		append(entries, entry)
	}
	return nil
}

// sysex body: heterogeneous sequence of scalars, arrays, and mappings
unmarshal_sysex_body :: proc(ctx: yaml.Unmarshal_Context, v: any) -> yaml.Unmarshal_Error {
	if yaml.unmarshal_ctx_node_type(ctx) != .SEQUENCE_NODE { return nil }
	body := (^[dynamic]Inst_Sysex_Element)(v.data)
	items := yaml.unmarshal_ctx_sequence_items(ctx)

	for item_id in items {
		item_node := yaml.unmarshal_ctx_get_node(ctx, item_id)
		if item_node == nil { continue }

		switch item_node.type {
		case .SCALAR_NODE:
			// Integer literal: 0xF0
			s := node_scalar(item_node)
			if ival, ok := parse_yaml_int(s); ok {
				append(body, Inst_Sysex_Element{kind = .Literal, value = u8(ival)})
			}

		case .SEQUENCE_NODE:
			// Array of literals: [0x00, 0x21, 0x7F] → expand to multiple Literal elements
			sub_items := yaml.unmarshal_ctx_sequence_items(
				yaml.Unmarshal_Context{doc = ctx.doc, node = item_node, allocator = ctx.allocator},
			)
			for sub_id in sub_items {
				sub_node := yaml.unmarshal_ctx_get_node(ctx, sub_id)
				if sub_node == nil { continue }
				s := node_scalar(sub_node)
				if ival, ok := parse_yaml_int(s); ok {
					append(body, Inst_Sysex_Element{kind = .Literal, value = u8(ival)})
				}
			}

		case .MAPPING_NODE:
			// Typed element: { type: channel, base: 0x30 }
			elem := unmarshal_sysex_mapping(ctx, item_node)
			append(body, elem)

		case .NO_NODE:
			// skip
		}
	}
	return nil
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

@(private)
node_scalar :: proc(node: ^yaml.node_t) -> string {
	if node == nil || node.type != .SCALAR_NODE { return "" }
	value := node.data.scalar.value
	length := node.data.scalar.length
	if value == nil || length == 0 { return "" }
	return string(value[:length])
}

@(private)
is_cc_field :: proc(key: string) -> bool {
	switch key {
	case "name", "cc", "default", "enum", "signed", "array":
		return true
	}
	return false
}

@(private)
is_cc14_field :: proc(key: string) -> bool {
	switch key {
	case "name", "msb", "lsb", "enum", "signed":
		return true
	}
	return false
}

@(private)
parse_yaml_int :: proc(s: string) -> (val: int, ok: bool) {
	if len(s) == 0 { return 0, false }
	str := s
	negative := false
	if str[0] == '-' {
		negative = true
		str = str[1:]
	} else if str[0] == '+' {
		str = str[1:]
	}
	result: int
	if len(str) > 2 && str[0] == '0' {
		switch str[1] {
		case 'x', 'X':
			v, parse_ok := strconv.parse_int(str[2:], 16)
			if !parse_ok { return 0, false }
			result = v
		case 'o', 'O':
			v, parse_ok := strconv.parse_int(str[2:], 8)
			if !parse_ok { return 0, false }
			result = v
		case:
			v, parse_ok := strconv.parse_int(str)
			if !parse_ok { return 0, false }
			result = v
		}
	} else {
		v, parse_ok := strconv.parse_int(str)
		if !parse_ok { return 0, false }
		result = v
	}
	if negative { result = -result }
	return result, true
}

@(private)
unmarshal_sysex_mapping :: proc(ctx: yaml.Unmarshal_Context, node: ^yaml.node_t) -> Inst_Sysex_Element {
	elem: Inst_Sysex_Element
	sub_ctx := yaml.Unmarshal_Context{doc = ctx.doc, node = node, allocator = ctx.allocator}
	pairs := yaml.unmarshal_ctx_mapping_pairs(sub_ctx)

	type_str: string
	name_str: string
	base_val: Maybe(int)

	for pair in pairs {
		key_node := yaml.unmarshal_ctx_get_node(ctx, pair.key)
		val_node := yaml.unmarshal_ctx_get_node(ctx, pair.value)
		if key_node == nil || val_node == nil { continue }

		key := node_scalar(key_node)
		switch key {
		case "type":
			type_str = node_scalar(val_node)
		case "name":
			name_str = node_scalar(val_node)
		case "base":
			if bv, ok := parse_yaml_int(node_scalar(val_node)); ok {
				base_val = bv
			}
		}
	}

	switch type_str {
	case "channel":
		elem.kind = .Channel
		elem.base = base_val
	case "device_id":
		elem.kind = .Device_Id
	case "checksum":
		elem.kind = .Checksum
	case "param":
		elem.kind = .Param_Ref
		elem.name = strings.clone(name_str, ctx.allocator) or_else ""
	case "vararg":
		elem.kind = .Vararg
		elem.name = strings.clone(name_str, ctx.allocator) or_else ""
	}

	return elem
}

// ---------------------------------------------------------------------------
// Main
// ---------------------------------------------------------------------------

main :: proc() {
	data, read_err := os.read_entire_file("inst/benchmark.yaml", context.allocator)
	if read_err != nil {
		data, read_err = os.read_entire_file("benchmark.yaml", context.allocator)
		if read_err != nil {
			fmt.eprintln("Error: failed to read benchmark_synth.yaml:", read_err)
			os.exit(1)
		}
	}
	defer delete(data, context.allocator)

	// Register custom unmarshalers
	unmarshalers: map[typeid]yaml.User_Unmarshaler
	defer delete(unmarshalers)
	register_inst_unmarshalers(&unmarshalers)
	defer yaml.set_user_unmarshalers(nil)

	inst: Inst
	arena_alloc := inst_init(&inst)
	defer inst_destroy(&inst)

	err := yaml.unmarshal(data, &inst, arena_alloc)
	if err != nil {
		fmt.eprintln("Unmarshal error:", err)
		os.exit(1)
	}

	// --- 結果表示 ---
	fmt.println("=== Instrument ===")
	fmt.printfln("name:            %s", inst.name)
	fmt.printfln("vendor:          %s", inst.vendor)
	fmt.printf("manufacturer_id: [")
	for v, i in inst.manufacturer_id {
		if i > 0 { fmt.printf(", ") }
		fmt.printf("0x%02X", v)
	}
	fmt.println("]")
	fmt.printf("model_id:        [")
	for v, i in inst.model_id {
		if i > 0 { fmt.printf(", ") }
		fmt.printf("0x%02X", v)
	}
	fmt.println("]")

	if ch, has_ch := inst.channel.?; has_ch {
		fmt.printfln("channel:         %d", ch)
	}

	// note
	if note, has := inst.note.?; has {
		fmt.printfln("\n--- note ---")
		fmt.printfln("  velocity: %v", note.velocity)
		fmt.printfln("  range:    [%d, %d]", note.range.min, note.range.max)
	}

	// bend
	if bend, has := inst.bend.?; has {
		fmt.printfln("\n--- bend ---")
		if bend.up != 0 || bend.down != 0 {
			fmt.printfln("  up: %d, down: %d", bend.up, bend.down)
		}
		if bend.range_ != 0 {
			fmt.printfln("  range: %d", bend.range_)
		}
	}

	// aftertouch
	if at, has := inst.aftertouch.?; has {
		fmt.printfln("\n--- aftertouch ---")
		fmt.printfln("  type: %v", at)
	}

	// program
	if prog, has := inst.program.?; has {
		fmt.printfln("\n--- program ---")
		fmt.printfln("  range: [%d, %d]", prog.min, prog.max)
	}

	// bank
	if bank, has := inst.bank.?; has {
		fmt.printfln("\n--- bank ---")
		if msb, has_msb := bank.msb.?; has_msb {
			fmt.printfln("  msb: [%d, %d]", msb.min, msb.max)
		}
		if lsb, has_lsb := bank.lsb.?; has_lsb {
			fmt.printfln("  lsb: [%d, %d]", lsb.min, lsb.max)
		}
		fmt.printfln("  program: [%d, %d]", bank.program.min, bank.program.max)
	}

	// drum
	if len(inst.drum) > 0 {
		fmt.printfln("\n--- drum (%d entries) ---", len(inst.drum))
		for d in inst.drum {
			fmt.printfln("  %s: %d", d.name, d.note_number)
		}
	}

	// cc
	if len(inst.cc) > 0 {
		fmt.printfln("\n--- cc (%d entries) ---", len(inst.cc))
		for cc in inst.cc {
			fmt.printf("  %s (cc=%d)", cc.name, cc.cc)
			if dv, has_dv := cc.default_value.?; has_dv {
				fmt.printf(" default=%d", dv)
			}
			if sr, has_sr := cc.signed_range.?; has_sr {
				fmt.printf(" signed=[%d,%d]+%d", sr.min, sr.max, sr.offset)
			}
			if ar, has_ar := cc.array_range.?; has_ar {
				fmt.printf(" array=[%d..%d step %d]", ar.from, ar.to, ar.step)
			}
			if len(cc.enum_entries) > 0 {
				fmt.print(" enum={")
				for e, i in cc.enum_entries {
					if i > 0 { fmt.printf(", ") }
					if e.min_value == e.max_value {
						fmt.printf("%s=%d", e.label, e.min_value)
					} else {
						fmt.printf("%s=[%d,%d]", e.label, e.min_value, e.max_value)
					}
				}
				fmt.print("}")
			}
			fmt.println()
		}
	}

	// cc14
	if len(inst.cc14) > 0 {
		fmt.printfln("\n--- cc14 (%d entries) ---", len(inst.cc14))
		for cc14 in inst.cc14 {
			fmt.printf("  %s (msb=%d, lsb=%d)", cc14.name, cc14.msb, cc14.lsb)
			if sr, has_sr := cc14.signed_range.?; has_sr {
				fmt.printf(" signed=[%d,%d]+%d", sr.min, sr.max, sr.offset)
			}
			if len(cc14.enum_entries) > 0 {
				fmt.print(" enum={")
				for e, i in cc14.enum_entries {
					if i > 0 { fmt.printf(", ") }
					fmt.printf("%s=[%d,%d]", e.label, e.min_value, e.max_value)
				}
				fmt.print("}")
			}
			fmt.println()
		}
	}

	// nrpn
	if len(inst.nrpn) > 0 {
		fmt.printfln("\n--- nrpn (%d entries) ---", len(inst.nrpn))
		for n in inst.nrpn {
			fmt.printf("  %s (msb=%d, lsb=%d", n.name, n.msb, n.lsb)
			if n.lsb_is_note { fmt.printf(" [note]") }
			fmt.printf(")")
			if vr, has_vr := n.value_range.?; has_vr {
				fmt.printf(" range=[%d,%d]", vr.min, vr.max)
			}
			if sr, has_sr := n.signed_range.?; has_sr {
				fmt.printf(" signed=[%d,%d]+%d", sr.min, sr.max, sr.offset)
			}
			if ar, has_ar := n.array_range.?; has_ar {
				fmt.printf(" array=[%d..%d step %d]", ar.from, ar.to, ar.step)
			}
			if len(n.enum_entries) > 0 {
				fmt.print(" enum={")
				for e, i in n.enum_entries {
					if i > 0 { fmt.printf(", ") }
					fmt.printf("%s=%d", e.label, e.min_value)
				}
				fmt.print("}")
			}
			fmt.println()
		}
	}

	// rpn
	if len(inst.rpn) > 0 {
		fmt.printfln("\n--- rpn (%d entries) ---", len(inst.rpn))
		for r in inst.rpn {
			fmt.printf("  %s (msb=%d, lsb=%d)", r.name, r.msb, r.lsb)
			if vr, has_vr := r.value_range.?; has_vr {
				fmt.printf(" range=[%d,%d]", vr.min, vr.max)
			}
			if sr, has_sr := r.signed_range.?; has_sr {
				fmt.printf(" signed=[%d,%d]+%d", sr.min, sr.max, sr.offset)
			}
			fmt.println()
		}
	}

	// layers
	if len(inst.layers) > 0 {
		fmt.printfln("\n--- layers (%d entries) ---", len(inst.layers))
		for l in inst.layers {
			fmt.printfln("  %s (offset=%d)", l.name, l.nrpn_offset)
		}
	}

	// sysex
	if len(inst.sysex) > 0 {
		fmt.printfln("\n--- sysex (%d entries) ---", len(inst.sysex))
		for sx in inst.sysex {
			fmt.printf("  %s", sx.name)
			if len(sx.params) > 0 {
				fmt.printf(" params=[")
				for p, i in sx.params {
					if i > 0 { fmt.printf(", ") }
					fmt.printf("%s", p)
				}
				fmt.printf("]")
			}
			fmt.printfln(" body_len=%d", len(sx.body))
			for elem in sx.body {
				switch elem.kind {
				case .Literal:
					fmt.printfln("    Literal: 0x%02X", elem.value)
				case .Param_Ref:
					fmt.printfln("    Param_Ref: %s", elem.name)
				case .Channel:
					if base, has_base := elem.base.?; has_base {
						fmt.printfln("    Channel (base=0x%02X)", base)
					} else {
						fmt.printfln("    Channel")
					}
				case .Device_Id:
					fmt.printfln("    Device_Id")
				case .Checksum:
					fmt.printfln("    Checksum")
				case .Vararg:
					fmt.printfln("    Vararg: %s", elem.name)
				}
			}
		}
	}

	fmt.println("\n=== Done ===")
}
