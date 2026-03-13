// Generated from include/yaml.h (libyaml 0.2.5)
package yaml

import "core:c"
import "core:c/libc"

LIBYAML_SHARED :: #config(LIBYAML_SHARED, false)

when LIBYAML_SHARED {
	when ODIN_OS == .Windows {
		foreign import lib "windows/libyaml.dll"
	} else when ODIN_OS == .Darwin && ODIN_ARCH == .arm64 {
		foreign import lib "macos/libyaml.dylib"
	}
} else {
	when ODIN_OS == .Windows {
		foreign import lib "windows/libyaml.lib"
	} else when ODIN_OS == .Darwin {
		foreign import lib "macos/libyaml.a"
	}
}

// ---------------------------------------------------------------------------
// Version
// ---------------------------------------------------------------------------

@(default_calling_convention = "c", link_prefix = "yaml_")
foreign lib {
	get_version_string :: proc() -> cstring ---
	get_version :: proc(major: ^c.int, minor: ^c.int, patch: ^c.int) ---
}

// ---------------------------------------------------------------------------
// Basic Types
// ---------------------------------------------------------------------------

char_t :: c.uchar

version_directive_t :: struct {
	major: c.int,
	minor: c.int,
}

tag_directive_t :: struct {
	handle: [^]char_t,
	prefix: [^]char_t,
}

encoding_t :: enum c.int {
	ANY_ENCODING     = 0,
	UTF8_ENCODING    = 1,
	UTF16LE_ENCODING = 2,
	UTF16BE_ENCODING = 3,
}

break_t :: enum c.int {
	ANY_BREAK  = 0,
	CR_BREAK   = 1,
	LN_BREAK   = 2,
	CRLN_BREAK = 3,
}

error_type_t :: enum c.int {
	NO_ERROR       = 0,
	MEMORY_ERROR   = 1,
	READER_ERROR   = 2,
	SCANNER_ERROR  = 3,
	PARSER_ERROR   = 4,
	COMPOSER_ERROR = 5,
	WRITER_ERROR   = 6,
	EMITTER_ERROR  = 7,
}

mark_t :: struct {
	index:  c.size_t,
	line:   c.size_t,
	column: c.size_t,
}

// ---------------------------------------------------------------------------
// Node Styles
// ---------------------------------------------------------------------------

scalar_style_t :: enum c.int {
	ANY_SCALAR_STYLE           = 0,
	PLAIN_SCALAR_STYLE         = 1,
	SINGLE_QUOTED_SCALAR_STYLE = 2,
	DOUBLE_QUOTED_SCALAR_STYLE = 3,
	LITERAL_SCALAR_STYLE       = 4,
	FOLDED_SCALAR_STYLE        = 5,
}

sequence_style_t :: enum c.int {
	ANY_SEQUENCE_STYLE   = 0,
	BLOCK_SEQUENCE_STYLE = 1,
	FLOW_SEQUENCE_STYLE  = 2,
}

mapping_style_t :: enum c.int {
	ANY_MAPPING_STYLE   = 0,
	BLOCK_MAPPING_STYLE = 1,
	FLOW_MAPPING_STYLE  = 2,
}

// ---------------------------------------------------------------------------
// Tokens
// ---------------------------------------------------------------------------

token_type_t :: enum c.int {
	NO_TOKEN                   = 0,
	STREAM_START_TOKEN         = 1,
	STREAM_END_TOKEN           = 2,
	VERSION_DIRECTIVE_TOKEN    = 3,
	TAG_DIRECTIVE_TOKEN        = 4,
	DOCUMENT_START_TOKEN       = 5,
	DOCUMENT_END_TOKEN         = 6,
	BLOCK_SEQUENCE_START_TOKEN = 7,
	BLOCK_MAPPING_START_TOKEN  = 8,
	BLOCK_END_TOKEN            = 9,
	FLOW_SEQUENCE_START_TOKEN  = 10,
	FLOW_SEQUENCE_END_TOKEN    = 11,
	FLOW_MAPPING_START_TOKEN   = 12,
	FLOW_MAPPING_END_TOKEN     = 13,
	BLOCK_ENTRY_TOKEN          = 14,
	FLOW_ENTRY_TOKEN           = 15,
	KEY_TOKEN                  = 16,
	VALUE_TOKEN                = 17,
	ALIAS_TOKEN                = 18,
	ANCHOR_TOKEN               = 19,
	TAG_TOKEN                  = 20,
	SCALAR_TOKEN               = 21,
}

token_t :: struct {
	type: token_type_t,
	data: struct #raw_union {
		stream_start: struct {
			encoding: encoding_t,
		},
		alias: struct {
			value: [^]char_t,
		},
		anchor: struct {
			value: [^]char_t,
		},
		tag: struct {
			handle: [^]char_t,
			suffix: [^]char_t,
		},
		scalar: struct {
			value:  [^]char_t,
			length: c.size_t,
			style:  scalar_style_t,
		},
		version_directive: struct {
			major: c.int,
			minor: c.int,
		},
		tag_directive: struct {
			handle: [^]char_t,
			prefix: [^]char_t,
		},
	},
	start_mark: mark_t,
	end_mark:   mark_t,
}

@(default_calling_convention = "c", link_prefix = "yaml_")
foreign lib {
	token_delete :: proc(token: ^token_t) ---
}

// ---------------------------------------------------------------------------
// Events
// ---------------------------------------------------------------------------

event_type_t :: enum c.int {
	NO_EVENT             = 0,
	STREAM_START_EVENT   = 1,
	STREAM_END_EVENT     = 2,
	DOCUMENT_START_EVENT = 3,
	DOCUMENT_END_EVENT   = 4,
	ALIAS_EVENT          = 5,
	SCALAR_EVENT         = 6,
	SEQUENCE_START_EVENT = 7,
	SEQUENCE_END_EVENT   = 8,
	MAPPING_START_EVENT  = 9,
	MAPPING_END_EVENT    = 10,
}

event_t :: struct {
	type: event_type_t,
	data: struct #raw_union {
		stream_start: struct {
			encoding: encoding_t,
		},
		document_start: struct {
			version_directive: ^version_directive_t,
			tag_directives: struct {
				start: [^]tag_directive_t,
				end:   [^]tag_directive_t,
			},
			implicit: c.int,
		},
		document_end: struct {
			implicit: c.int,
		},
		alias: struct {
			anchor: [^]char_t,
		},
		scalar: struct {
			anchor:          [^]char_t,
			tag:             [^]char_t,
			value:           [^]char_t,
			length:          c.size_t,
			plain_implicit:  c.int,
			quoted_implicit: c.int,
			style:           scalar_style_t,
		},
		sequence_start: struct {
			anchor:   [^]char_t,
			tag:      [^]char_t,
			implicit: c.int,
			style:    sequence_style_t,
		},
		mapping_start: struct {
			anchor:   [^]char_t,
			tag:      [^]char_t,
			implicit: c.int,
			style:    mapping_style_t,
		},
	},
	start_mark: mark_t,
	end_mark:   mark_t,
}

@(default_calling_convention = "c", link_prefix = "yaml_")
foreign lib {
	stream_start_event_initialize :: proc(event: ^event_t, encoding: encoding_t) -> c.int ---
	stream_end_event_initialize :: proc(event: ^event_t) -> c.int ---
	document_start_event_initialize :: proc(event: ^event_t, version_directive: ^version_directive_t, tag_directives_start: [^]tag_directive_t, tag_directives_end: [^]tag_directive_t, implicit: c.int) -> c.int ---
	document_end_event_initialize :: proc(event: ^event_t, implicit: c.int) -> c.int ---
	alias_event_initialize :: proc(event: ^event_t, anchor: [^]char_t) -> c.int ---
	scalar_event_initialize :: proc(event: ^event_t, anchor: [^]char_t, tag: [^]char_t, value: [^]char_t, length: c.int, plain_implicit: c.int, quoted_implicit: c.int, style: scalar_style_t) -> c.int ---
	sequence_start_event_initialize :: proc(event: ^event_t, anchor: [^]char_t, tag: [^]char_t, implicit: c.int, style: sequence_style_t) -> c.int ---
	sequence_end_event_initialize :: proc(event: ^event_t) -> c.int ---
	mapping_start_event_initialize :: proc(event: ^event_t, anchor: [^]char_t, tag: [^]char_t, implicit: c.int, style: mapping_style_t) -> c.int ---
	mapping_end_event_initialize :: proc(event: ^event_t) -> c.int ---
	event_delete :: proc(event: ^event_t) ---
}

// ---------------------------------------------------------------------------
// Nodes & Documents
// ---------------------------------------------------------------------------

YAML_NULL_TAG      :: "tag:yaml.org,2002:null"
YAML_BOOL_TAG      :: "tag:yaml.org,2002:bool"
YAML_STR_TAG       :: "tag:yaml.org,2002:str"
YAML_INT_TAG       :: "tag:yaml.org,2002:int"
YAML_FLOAT_TAG     :: "tag:yaml.org,2002:float"
YAML_TIMESTAMP_TAG :: "tag:yaml.org,2002:timestamp"
YAML_SEQ_TAG       :: "tag:yaml.org,2002:seq"
YAML_MAP_TAG       :: "tag:yaml.org,2002:map"

YAML_DEFAULT_SCALAR_TAG   :: YAML_STR_TAG
YAML_DEFAULT_SEQUENCE_TAG :: YAML_SEQ_TAG
YAML_DEFAULT_MAPPING_TAG  :: YAML_MAP_TAG

node_type_t :: enum c.int {
	NO_NODE       = 0,
	SCALAR_NODE   = 1,
	SEQUENCE_NODE = 2,
	MAPPING_NODE  = 3,
}

node_item_t :: c.int

node_pair_t :: struct {
	key:   c.int,
	value: c.int,
}

node_t :: struct {
	type: node_type_t,
	tag:  [^]char_t,
	data: struct #raw_union {
		scalar: struct {
			value:  [^]char_t,
			length: c.size_t,
			style:  scalar_style_t,
		},
		sequence: struct {
			items: struct {
				start: [^]node_item_t,
				end:   [^]node_item_t,
				top:   [^]node_item_t,
			},
			style: sequence_style_t,
		},
		mapping: struct {
			pairs: struct {
				start: [^]node_pair_t,
				end:   [^]node_pair_t,
				top:   [^]node_pair_t,
			},
			style: mapping_style_t,
		},
	},
	start_mark: mark_t,
	end_mark:   mark_t,
}

document_t :: struct {
	nodes: struct {
		start: [^]node_t,
		end:   [^]node_t,
		top:   [^]node_t,
	},
	version_directive: ^version_directive_t,
	tag_directives: struct {
		start: [^]tag_directive_t,
		end:   [^]tag_directive_t,
	},
	start_implicit: c.int,
	end_implicit:   c.int,
	start_mark:     mark_t,
	end_mark:       mark_t,
}

@(default_calling_convention = "c", link_prefix = "yaml_")
foreign lib {
	document_initialize :: proc(document: ^document_t, version_directive: ^version_directive_t, tag_directives_start: [^]tag_directive_t, tag_directives_end: [^]tag_directive_t, start_implicit: c.int, end_implicit: c.int) -> c.int ---
	document_delete :: proc(document: ^document_t) ---
	document_get_node :: proc(document: ^document_t, index: c.int) -> ^node_t ---
	document_get_root_node :: proc(document: ^document_t) -> ^node_t ---
	document_add_scalar :: proc(document: ^document_t, tag: [^]char_t, value: [^]char_t, length: c.int, style: scalar_style_t) -> c.int ---
	document_add_sequence :: proc(document: ^document_t, tag: [^]char_t, style: sequence_style_t) -> c.int ---
	document_add_mapping :: proc(document: ^document_t, tag: [^]char_t, style: mapping_style_t) -> c.int ---
	document_append_sequence_item :: proc(document: ^document_t, sequence: c.int, item: c.int) -> c.int ---
	document_append_mapping_pair :: proc(document: ^document_t, mapping: c.int, key: c.int, value: c.int) -> c.int ---
}

// ---------------------------------------------------------------------------
// Parser
// ---------------------------------------------------------------------------

read_handler_t :: #type proc "c" (data: rawptr, buffer: [^]c.uchar, size: c.size_t, size_read: ^c.size_t) -> c.int

simple_key_t :: struct {
	possible:     c.int,
	required:     c.int,
	token_number: c.size_t,
	mark:         mark_t,
}

parser_state_t :: enum c.int {
	STREAM_START_STATE                      = 0,
	IMPLICIT_DOCUMENT_START_STATE           = 1,
	DOCUMENT_START_STATE                    = 2,
	DOCUMENT_CONTENT_STATE                  = 3,
	DOCUMENT_END_STATE                      = 4,
	BLOCK_NODE_STATE                        = 5,
	BLOCK_NODE_OR_INDENTLESS_SEQUENCE_STATE = 6,
	FLOW_NODE_STATE                         = 7,
	BLOCK_SEQUENCE_FIRST_ENTRY_STATE        = 8,
	BLOCK_SEQUENCE_ENTRY_STATE              = 9,
	INDENTLESS_SEQUENCE_ENTRY_STATE         = 10,
	BLOCK_MAPPING_FIRST_KEY_STATE           = 11,
	BLOCK_MAPPING_KEY_STATE                 = 12,
	BLOCK_MAPPING_VALUE_STATE               = 13,
	FLOW_SEQUENCE_FIRST_ENTRY_STATE         = 14,
	FLOW_SEQUENCE_ENTRY_STATE               = 15,
	FLOW_SEQUENCE_ENTRY_MAPPING_KEY_STATE   = 16,
	FLOW_SEQUENCE_ENTRY_MAPPING_VALUE_STATE = 17,
	FLOW_SEQUENCE_ENTRY_MAPPING_END_STATE   = 18,
	FLOW_MAPPING_FIRST_KEY_STATE            = 19,
	FLOW_MAPPING_KEY_STATE                  = 20,
	FLOW_MAPPING_VALUE_STATE                = 21,
	FLOW_MAPPING_EMPTY_VALUE_STATE          = 22,
	END_STATE                               = 23,
}

alias_data_t :: struct {
	anchor: [^]char_t,
	index:  c.int,
	mark:   mark_t,
}

parser_t :: struct {
	// Error handling
	error:          error_type_t,
	problem:        cstring,
	problem_offset: c.size_t,
	problem_value:  c.int,
	problem_mark:   mark_t,
	_context:       cstring,
	context_mark:   mark_t,

	// Reader
	read_handler:      read_handler_t,
	read_handler_data: rawptr,
	input: struct #raw_union {
		string: struct {
			start:   [^]c.uchar,
			end:     [^]c.uchar,
			current: [^]c.uchar,
		},
		file: ^libc.FILE,
	},
	eof: c.int,
	buffer: struct {
		start:   [^]char_t,
		end:     [^]char_t,
		pointer: [^]char_t,
		last:    [^]char_t,
	},
	unread: c.size_t,
	raw_buffer: struct {
		start:   [^]c.uchar,
		end:     [^]c.uchar,
		pointer: [^]c.uchar,
		last:    [^]c.uchar,
	},
	encoding: encoding_t,
	offset:   c.size_t,
	mark:     mark_t,

	// Scanner
	stream_start_produced: c.int,
	stream_end_produced:   c.int,
	flow_level:            c.int,
	tokens: struct {
		start: [^]token_t,
		end:   [^]token_t,
		head:  [^]token_t,
		tail:  [^]token_t,
	},
	tokens_parsed:   c.size_t,
	token_available: c.int,
	indents: struct {
		start: [^]c.int,
		end:   [^]c.int,
		top:   [^]c.int,
	},
	indent:            c.int,
	simple_key_allowed: c.int,
	simple_keys: struct {
		start: [^]simple_key_t,
		end:   [^]simple_key_t,
		top:   [^]simple_key_t,
	},

	// Parser
	states: struct {
		start: [^]parser_state_t,
		end:   [^]parser_state_t,
		top:   [^]parser_state_t,
	},
	state: parser_state_t,
	marks: struct {
		start: [^]mark_t,
		end:   [^]mark_t,
		top:   [^]mark_t,
	},
	tag_directives: struct {
		start: [^]tag_directive_t,
		end:   [^]tag_directive_t,
		top:   [^]tag_directive_t,
	},

	// Dumper
	aliases: struct {
		start: [^]alias_data_t,
		end:   [^]alias_data_t,
		top:   [^]alias_data_t,
	},
	document: ^document_t,
}

@(default_calling_convention = "c", link_prefix = "yaml_")
foreign lib {
	parser_initialize :: proc(parser: ^parser_t) -> c.int ---
	parser_delete :: proc(parser: ^parser_t) ---
	parser_set_input_string :: proc(parser: ^parser_t, input: [^]c.uchar, size: c.size_t) ---
	parser_set_input_file :: proc(parser: ^parser_t, file: ^libc.FILE) ---
	parser_set_input :: proc(parser: ^parser_t, handler: read_handler_t, data: rawptr) ---
	parser_set_encoding :: proc(parser: ^parser_t, encoding: encoding_t) ---
	parser_scan :: proc(parser: ^parser_t, token: ^token_t) -> c.int ---
	parser_parse :: proc(parser: ^parser_t, event: ^event_t) -> c.int ---
	parser_load :: proc(parser: ^parser_t, document: ^document_t) -> c.int ---
	set_max_nest_level :: proc(max: c.int) ---
}

// ---------------------------------------------------------------------------
// Emitter
// ---------------------------------------------------------------------------

write_handler_t :: #type proc "c" (data: rawptr, buffer: [^]c.uchar, size: c.size_t) -> c.int

emitter_state_t :: enum c.int {
	STREAM_START_STATE               = 0,
	FIRST_DOCUMENT_START_STATE       = 1,
	DOCUMENT_START_STATE             = 2,
	DOCUMENT_CONTENT_STATE           = 3,
	DOCUMENT_END_STATE               = 4,
	FLOW_SEQUENCE_FIRST_ITEM_STATE   = 5,
	FLOW_SEQUENCE_ITEM_STATE         = 6,
	FLOW_MAPPING_FIRST_KEY_STATE     = 7,
	FLOW_MAPPING_KEY_STATE           = 8,
	FLOW_MAPPING_SIMPLE_VALUE_STATE  = 9,
	FLOW_MAPPING_VALUE_STATE         = 10,
	BLOCK_SEQUENCE_FIRST_ITEM_STATE  = 11,
	BLOCK_SEQUENCE_ITEM_STATE        = 12,
	BLOCK_MAPPING_FIRST_KEY_STATE    = 13,
	BLOCK_MAPPING_KEY_STATE          = 14,
	BLOCK_MAPPING_SIMPLE_VALUE_STATE = 15,
	BLOCK_MAPPING_VALUE_STATE        = 16,
	END_STATE                        = 17,
}

anchors_t :: struct {
	references: c.int,
	anchor:     c.int,
	serialized: c.int,
}

emitter_t :: struct {
	// Error handling
	error:   error_type_t,
	problem: cstring,

	// Writer
	write_handler:      write_handler_t,
	write_handler_data: rawptr,
	output: struct #raw_union {
		string: struct {
			buffer:       [^]c.uchar,
			size:         c.size_t,
			size_written: ^c.size_t,
		},
		file: ^libc.FILE,
	},
	buffer: struct {
		start:   [^]char_t,
		end:     [^]char_t,
		pointer: [^]char_t,
		last:    [^]char_t,
	},
	raw_buffer: struct {
		start:   [^]c.uchar,
		end:     [^]c.uchar,
		pointer: [^]c.uchar,
		last:    [^]c.uchar,
	},
	encoding: encoding_t,

	// Emitter
	canonical:   c.int,
	best_indent: c.int,
	best_width:  c.int,
	unicode:     c.int,
	line_break:  break_t,
	states: struct {
		start: [^]emitter_state_t,
		end:   [^]emitter_state_t,
		top:   [^]emitter_state_t,
	},
	state: emitter_state_t,
	events: struct {
		start: [^]event_t,
		end:   [^]event_t,
		head:  [^]event_t,
		tail:  [^]event_t,
	},
	indents: struct {
		start: [^]c.int,
		end:   [^]c.int,
		top:   [^]c.int,
	},
	tag_directives: struct {
		start: [^]tag_directive_t,
		end:   [^]tag_directive_t,
		top:   [^]tag_directive_t,
	},
	indent:             c.int,
	flow_level:         c.int,
	root_context:       c.int,
	sequence_context:   c.int,
	mapping_context:    c.int,
	simple_key_context: c.int,
	line:               c.int,
	column:             c.int,
	whitespace:         c.int,
	indention:          c.int,
	open_ended:         c.int,
	anchor_data: struct {
		anchor:        [^]char_t,
		anchor_length: c.size_t,
		alias:         c.int,
	},
	tag_data: struct {
		handle:        [^]char_t,
		handle_length: c.size_t,
		suffix:        [^]char_t,
		suffix_length: c.size_t,
	},
	scalar_data: struct {
		value:                [^]char_t,
		length:               c.size_t,
		multiline:            c.int,
		flow_plain_allowed:   c.int,
		block_plain_allowed:  c.int,
		single_quoted_allowed: c.int,
		block_allowed:        c.int,
		style:                scalar_style_t,
	},

	// Dumper
	opened:         c.int,
	closed:         c.int,
	anchors:        [^]anchors_t,
	last_anchor_id: c.int,
	document:       ^document_t,
}

@(default_calling_convention = "c", link_prefix = "yaml_")
foreign lib {
	emitter_initialize :: proc(emitter: ^emitter_t) -> c.int ---
	emitter_delete :: proc(emitter: ^emitter_t) ---
	emitter_set_output_string :: proc(emitter: ^emitter_t, output: [^]c.uchar, size: c.size_t, size_written: ^c.size_t) ---
	emitter_set_output_file :: proc(emitter: ^emitter_t, file: ^libc.FILE) ---
	emitter_set_output :: proc(emitter: ^emitter_t, handler: write_handler_t, data: rawptr) ---
	emitter_set_encoding :: proc(emitter: ^emitter_t, encoding: encoding_t) ---
	emitter_set_canonical :: proc(emitter: ^emitter_t, canonical: c.int) ---
	emitter_set_indent :: proc(emitter: ^emitter_t, indent: c.int) ---
	emitter_set_width :: proc(emitter: ^emitter_t, width: c.int) ---
	emitter_set_unicode :: proc(emitter: ^emitter_t, unicode: c.int) ---
	emitter_set_break :: proc(emitter: ^emitter_t, line_break: break_t) ---
	emitter_emit :: proc(emitter: ^emitter_t, event: ^event_t) -> c.int ---
	emitter_open :: proc(emitter: ^emitter_t) -> c.int ---
	emitter_close :: proc(emitter: ^emitter_t) -> c.int ---
	emitter_dump :: proc(emitter: ^emitter_t, document: ^document_t) -> c.int ---
	emitter_flush :: proc(emitter: ^emitter_t) -> c.int ---
}
