package tests

import "core:fmt"
import "core:os"
import "core:strings"
import "core:testing"
import "core:c/libc"

import yaml ".."

// Helper: get all example YAML file paths
EXAMPLE_DIR :: "tests/examples/"

EXAMPLE_FILES := [?]string{
	EXAMPLE_DIR + "anchors.yaml",
	EXAMPLE_DIR + "array.yaml",
	EXAMPLE_DIR + "global-tag.yaml",
	EXAMPLE_DIR + "json.yaml",
	EXAMPLE_DIR + "mapping.yaml",
	EXAMPLE_DIR + "numbers.yaml",
	EXAMPLE_DIR + "strings.yaml",
	EXAMPLE_DIR + "tags.yaml",
	EXAMPLE_DIR + "yaml-version.yaml",
}

// ========================================================================
// test-version: Check version string consistency
// ========================================================================
@(test)
test_version :: proc(t: ^testing.T) {
	major, minor, patch: i32
	yaml.get_version(&major, &minor, &patch)

	version_string := yaml.get_version_string()
	expected := fmt.tprintf("%d.%d.%d", major, minor, patch)

	testing.expect(
		t,
		string(version_string) == expected,
		fmt.tprintf("version mismatch: get_version=%s, get_version_string=%s", expected, version_string),
	)

	fmt.printf("libyaml version: %s\n", version_string)
	fmt.printf("sizeof(token)  = %d\n", size_of(yaml.token_t))
	fmt.printf("sizeof(event)  = %d\n", size_of(yaml.event_t))
	fmt.printf("sizeof(parser) = %d\n", size_of(yaml.parser_t))
}

// ========================================================================
// run-scanner: Scan YAML files into tokens
// ========================================================================
@(test)
test_scanner :: proc(t: ^testing.T) {
	files := EXAMPLE_FILES

	for filename in files {
		cfilename := strings.clone_to_cstring(filename)
		defer delete(cfilename)

		file := libc.fopen(cfilename, "rb")
		if file == nil {
			testing.expectf(t, false, "failed to open '%s'", filename)
			continue
		}
		defer libc.fclose(file)

		parser: yaml.parser_t
		if yaml.parser_initialize(&parser) == 0 {
			testing.expectf(t, false, "failed to initialize parser for '%s'", filename)
			continue
		}
		defer yaml.parser_delete(&parser)

		yaml.parser_set_input_file(&parser, file)

		done := false
		count := 0
		scan_error := false

		for !done {
			token: yaml.token_t
			if yaml.parser_scan(&parser, &token) == 0 {
				scan_error = true
				break
			}

			done = (token.type == .STREAM_END_TOKEN)
			yaml.token_delete(&token)
			count += 1
		}

		testing.expectf(t, !scan_error, "scan FAILURE on '%s'", filename)
		if !scan_error {
			fmt.printf("Scanning '%s': SUCCESS (%d tokens)\n", filename, count)
		}
	}
}

// ========================================================================
// run-parser: Parse YAML files into events
// ========================================================================
@(test)
test_parser :: proc(t: ^testing.T) {
	files := EXAMPLE_FILES

	for filename in files {
		cfilename := strings.clone_to_cstring(filename)
		defer delete(cfilename)

		file := libc.fopen(cfilename, "rb")
		if file == nil {
			testing.expectf(t, false, "failed to open '%s'", filename)
			continue
		}
		defer libc.fclose(file)

		parser: yaml.parser_t
		if yaml.parser_initialize(&parser) == 0 {
			testing.expectf(t, false, "failed to initialize parser for '%s'", filename)
			continue
		}
		defer yaml.parser_delete(&parser)

		yaml.parser_set_input_file(&parser, file)

		done := false
		count := 0
		parse_error := false

		for !done {
			event: yaml.event_t
			if yaml.parser_parse(&parser, &event) == 0 {
				parse_error = true
				fmt.printf(
					"Parse error: %s\nLine: %d Column: %d\n",
					parser.problem,
					parser.problem_mark.line + 1,
					parser.problem_mark.column + 1,
				)
				break
			}

			done = (event.type == .STREAM_END_EVENT)
			yaml.event_delete(&event)
			count += 1
		}

		testing.expectf(t, !parse_error, "parse FAILURE on '%s'", filename)
		if !parse_error {
			fmt.printf("Parsing '%s': SUCCESS (%d events)\n", filename, count)
		}
	}
}

// ========================================================================
// run-loader: Load YAML documents
// ========================================================================
@(test)
test_loader :: proc(t: ^testing.T) {
	files := EXAMPLE_FILES

	for filename in files {
		cfilename := strings.clone_to_cstring(filename)
		defer delete(cfilename)

		file := libc.fopen(cfilename, "rb")
		if file == nil {
			testing.expectf(t, false, "failed to open '%s'", filename)
			continue
		}
		defer libc.fclose(file)

		parser: yaml.parser_t
		if yaml.parser_initialize(&parser) == 0 {
			testing.expectf(t, false, "failed to initialize parser for '%s'", filename)
			continue
		}
		defer yaml.parser_delete(&parser)

		yaml.parser_set_input_file(&parser, file)

		done := false
		count := 0
		load_error := false

		for !done {
			document: yaml.document_t
			if yaml.parser_load(&parser, &document) == 0 {
				load_error = true
				break
			}

			root := yaml.document_get_root_node(&document)
			done = (root == nil)

			yaml.document_delete(&document)

			if !done {
				count += 1
			}
		}

		testing.expectf(t, !load_error, "load FAILURE on '%s'", filename)
		if !load_error {
			fmt.printf("Loading '%s': SUCCESS (%d documents)\n", filename, count)
		}
	}
}

// ========================================================================
// run-emitter: Parse -> Emit -> Re-parse round-trip
// ========================================================================

BUFFER_SIZE :: 65536
MAX_EVENTS :: 1024

copy_event :: proc(event_to: ^yaml.event_t, event_from: ^yaml.event_t) -> i32 {
	switch event_from.type {
	case .STREAM_START_EVENT:
		return yaml.stream_start_event_initialize(event_to, event_from.data.stream_start.encoding)
	case .STREAM_END_EVENT:
		return yaml.stream_end_event_initialize(event_to)
	case .DOCUMENT_START_EVENT:
		return yaml.document_start_event_initialize(
			event_to,
			event_from.data.document_start.version_directive,
			event_from.data.document_start.tag_directives.start,
			event_from.data.document_start.tag_directives.end,
			event_from.data.document_start.implicit,
		)
	case .DOCUMENT_END_EVENT:
		return yaml.document_end_event_initialize(event_to, event_from.data.document_end.implicit)
	case .ALIAS_EVENT:
		return yaml.alias_event_initialize(event_to, event_from.data.alias.anchor)
	case .SCALAR_EVENT:
		return yaml.scalar_event_initialize(
			event_to,
			event_from.data.scalar.anchor,
			event_from.data.scalar.tag,
			event_from.data.scalar.value,
			i32(event_from.data.scalar.length),
			event_from.data.scalar.plain_implicit,
			event_from.data.scalar.quoted_implicit,
			event_from.data.scalar.style,
		)
	case .SEQUENCE_START_EVENT:
		return yaml.sequence_start_event_initialize(
			event_to,
			event_from.data.sequence_start.anchor,
			event_from.data.sequence_start.tag,
			event_from.data.sequence_start.implicit,
			event_from.data.sequence_start.style,
		)
	case .SEQUENCE_END_EVENT:
		return yaml.sequence_end_event_initialize(event_to)
	case .MAPPING_START_EVENT:
		return yaml.mapping_start_event_initialize(
			event_to,
			event_from.data.mapping_start.anchor,
			event_from.data.mapping_start.tag,
			event_from.data.mapping_start.implicit,
			event_from.data.mapping_start.style,
		)
	case .MAPPING_END_EVENT:
		return yaml.mapping_end_event_initialize(event_to)
	case .NO_EVENT:
		return 0
	}
	return 0
}

@(test)
test_emitter_round_trip :: proc(t: ^testing.T) {
	files := EXAMPLE_FILES

	for filename in files {
		cfilename := strings.clone_to_cstring(filename)
		defer delete(cfilename)

		file := libc.fopen(cfilename, "rb")
		if file == nil {
			testing.expectf(t, false, "failed to open '%s'", filename)
			continue
		}

		buffer: [BUFFER_SIZE + 1]u8
		written: uint
		events: [MAX_EVENTS]yaml.event_t
		event_number: uint = 0

		// Phase 1: Parse and emit
		parser: yaml.parser_t
		emitter: yaml.emitter_t

		ok := yaml.parser_initialize(&parser) != 0
		testing.expectf(t, ok, "failed to initialize parser for '%s'", filename)
		if !ok {
			libc.fclose(file)
			continue
		}

		yaml.parser_set_input_file(&parser, file)

		ok = yaml.emitter_initialize(&emitter) != 0
		testing.expectf(t, ok, "failed to initialize emitter for '%s'", filename)
		if !ok {
			yaml.parser_delete(&parser)
			libc.fclose(file)
			continue
		}

		yaml.emitter_set_output_string(&emitter, &buffer[0], BUFFER_SIZE, &written)

		done := false
		phase1_error := false

		for !done {
			event: yaml.event_t
			if yaml.parser_parse(&parser, &event) == 0 {
				phase1_error = true
				break
			}

			done = (event.type == .STREAM_END_EVENT)

			if event_number < MAX_EVENTS {
				copy_event(&events[event_number], &event)
				event_number += 1
			}

			if yaml.emitter_emit(&emitter, &event) == 0 {
				phase1_error = true
				break
			}
		}

		yaml.parser_delete(&parser)
		libc.fclose(file)
		yaml.emitter_delete(&emitter)

		if phase1_error {
			// cleanup events
			for k: uint = 0; k < event_number; k += 1 {
				yaml.event_delete(&events[k])
			}
			testing.expectf(t, false, "emitter phase 1 FAILURE on '%s'", filename)
			continue
		}

		// Phase 2: Re-parse the emitted output and compare events
		parser2: yaml.parser_t
		ok = yaml.parser_initialize(&parser2) != 0
		testing.expectf(t, ok, "failed to initialize parser2 for '%s'", filename)
		if !ok {
			for k: uint = 0; k < event_number; k += 1 {
				yaml.event_delete(&events[k])
			}
			continue
		}

		yaml.parser_set_input_string(&parser2, &buffer[0], written)

		done = false
		count: uint = 0
		phase2_error := false

		for !done {
			event: yaml.event_t
			if yaml.parser_parse(&parser2, &event) == 0 {
				phase2_error = true
				break
			}

			done = (event.type == .STREAM_END_EVENT)

			// Compare event types at minimum
			if count < event_number {
				if events[count].type != event.type {
					fmt.printf(
						"Event mismatch at #%d: original=%v, re-parsed=%v\n",
						count,
						events[count].type,
						event.type,
					)
					phase2_error = true
				}
			}

			yaml.event_delete(&event)
			count += 1
		}

		yaml.parser_delete(&parser2)

		for k: uint = 0; k < event_number; k += 1 {
			yaml.event_delete(&events[k])
		}

		testing.expectf(t, !phase2_error, "emitter round-trip FAILURE on '%s'", filename)
		if !phase2_error {
			fmt.printf("Emitter round-trip '%s': PASSED (length: %d)\n", filename, written)
		}
	}
}

// ========================================================================
// test_parser_string_input: Parse YAML from string
// ========================================================================
@(test)
test_parser_string_input :: proc(t: ^testing.T) {
	input := `
name: John Doe
age: 30
items:
  - apple
  - banana
  - cherry
`
	parser: yaml.parser_t
	if yaml.parser_initialize(&parser) == 0 {
		testing.expect(t, false, "failed to initialize parser")
		return
	}
	defer yaml.parser_delete(&parser)

	yaml.parser_set_input_string(&parser, raw_data(input), len(input))

	done := false
	count := 0
	parse_error := false
	event_types: [dynamic]yaml.event_type_t
	defer delete(event_types)

	for !done {
		event: yaml.event_t
		if yaml.parser_parse(&parser, &event) == 0 {
			parse_error = true
			break
		}

		append(&event_types, event.type)
		done = (event.type == .STREAM_END_EVENT)
		yaml.event_delete(&event)
		count += 1
	}

	testing.expect(t, !parse_error, "string input parse error")
	testing.expectf(t, count > 0, "expected events, got %d", count)

	// Verify stream structure
	testing.expect(t, event_types[0] == .STREAM_START_EVENT, "first event should be STREAM_START")
	testing.expect(
		t,
		event_types[len(event_types) - 1] == .STREAM_END_EVENT,
		"last event should be STREAM_END",
	)

	fmt.printf("String input parsing: SUCCESS (%d events)\n", count)
}

// ========================================================================
// test_loader_string_input: Load document from string
// ========================================================================
@(test)
test_loader_string_input :: proc(t: ^testing.T) {
	input := `
- first
- second
- third
`
	parser: yaml.parser_t
	if yaml.parser_initialize(&parser) == 0 {
		testing.expect(t, false, "failed to initialize parser")
		return
	}
	defer yaml.parser_delete(&parser)

	yaml.parser_set_input_string(&parser, raw_data(input), len(input))

	document: yaml.document_t
	if yaml.parser_load(&parser, &document) == 0 {
		testing.expect(t, false, "failed to load document")
		return
	}
	defer yaml.document_delete(&document)

	root := yaml.document_get_root_node(&document)
	testing.expect(t, root != nil, "expected root node")
	if root != nil {
		testing.expectf(
			t,
			root.type == .SEQUENCE_NODE,
			"expected SEQUENCE_NODE, got %v",
			root.type,
		)
		fmt.printf("Loaded sequence document: root type = %v\n", root.type)
	}
}

// ========================================================================
// test_emitter_to_string: Build and emit a simple document
// ========================================================================
@(test)
test_emitter_to_string :: proc(t: ^testing.T) {
	emitter: yaml.emitter_t
	if yaml.emitter_initialize(&emitter) == 0 {
		testing.expect(t, false, "failed to initialize emitter")
		return
	}
	defer yaml.emitter_delete(&emitter)

	buffer: [4096]u8
	written: uint
	yaml.emitter_set_output_string(&emitter, &buffer[0], 4096, &written)

	event: yaml.event_t

	// STREAM-START
	testing.expect(
		t,
		yaml.stream_start_event_initialize(&event, .UTF8_ENCODING) != 0,
		"stream_start init failed",
	)
	testing.expect(t, yaml.emitter_emit(&emitter, &event) != 0, "emit stream_start failed")

	// DOCUMENT-START
	testing.expect(
		t,
		yaml.document_start_event_initialize(&event, nil, nil, nil, 1) != 0,
		"doc_start init failed",
	)
	testing.expect(t, yaml.emitter_emit(&emitter, &event) != 0, "emit doc_start failed")

	// MAPPING-START
	testing.expect(
		t,
		yaml.mapping_start_event_initialize(&event, nil, nil, 1, .BLOCK_MAPPING_STYLE) != 0,
		"mapping_start init failed",
	)
	testing.expect(t, yaml.emitter_emit(&emitter, &event) != 0, "emit mapping_start failed")

	// key: "hello"
	hello := "hello"
	testing.expect(
		t,
		yaml.scalar_event_initialize(
			&event,
			nil,
			nil,
			raw_data(hello),
			i32(len(hello)),
			1,
			1,
			.PLAIN_SCALAR_STYLE,
		) !=
			0,
		"scalar key init failed",
	)
	testing.expect(t, yaml.emitter_emit(&emitter, &event) != 0, "emit scalar key failed")

	// value: "world"
	world := "world"
	testing.expect(
		t,
		yaml.scalar_event_initialize(
			&event,
			nil,
			nil,
			raw_data(world),
			i32(len(world)),
			1,
			1,
			.PLAIN_SCALAR_STYLE,
		) !=
			0,
		"scalar value init failed",
	)
	testing.expect(t, yaml.emitter_emit(&emitter, &event) != 0, "emit scalar value failed")

	// MAPPING-END
	testing.expect(
		t,
		yaml.mapping_end_event_initialize(&event) != 0,
		"mapping_end init failed",
	)
	testing.expect(t, yaml.emitter_emit(&emitter, &event) != 0, "emit mapping_end failed")

	// DOCUMENT-END
	testing.expect(
		t,
		yaml.document_end_event_initialize(&event, 1) != 0,
		"doc_end init failed",
	)
	testing.expect(t, yaml.emitter_emit(&emitter, &event) != 0, "emit doc_end failed")

	// STREAM-END
	testing.expect(
		t,
		yaml.stream_end_event_initialize(&event) != 0,
		"stream_end init failed",
	)
	testing.expect(t, yaml.emitter_emit(&emitter, &event) != 0, "emit stream_end failed")

	output := string(buffer[:written])
	testing.expect(t, written > 0, "emitter produced no output")
	fmt.printf("Emitted YAML:\n%s", output)

	// Verify the output can be parsed back
	parser: yaml.parser_t
	testing.expect(t, yaml.parser_initialize(&parser) != 0, "parser init failed")
	defer yaml.parser_delete(&parser)
	yaml.parser_set_input_string(&parser, &buffer[0], written)

	doc: yaml.document_t
	testing.expect(t, yaml.parser_load(&parser, &doc) != 0, "re-parse failed")
	defer yaml.document_delete(&doc)

	root := yaml.document_get_root_node(&doc)
	testing.expect(t, root != nil, "re-parsed document has no root")
	if root != nil {
		testing.expectf(
			t,
			root.type == .MAPPING_NODE,
			"expected MAPPING_NODE, got %v",
			root.type,
		)
	}
}
