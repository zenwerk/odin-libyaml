// Example: Construct YAML output using the document/dumper API
package dumper_example

import "core:c"
import "core:fmt"
import yaml "../.."

BUFFER_SIZE :: 64 * 1024

main :: proc() {
	output_buffer: [BUFFER_SIZE]c.uchar
	written: c.size_t

	emitter: yaml.emitter_t
	if yaml.emitter_initialize(&emitter) == 0 {
		fmt.eprintln("Failed to initialize emitter")
		return
	}
	defer yaml.emitter_delete(&emitter)

	yaml.emitter_set_output_string(
		&emitter,
		raw_data(output_buffer[:]),
		BUFFER_SIZE,
		&written,
	)
	yaml.emitter_set_unicode(&emitter, 1)

	// Open the emitter stream
	yaml.emitter_open(&emitter)

	// Create a document
	document: yaml.document_t
	yaml.document_initialize(&document, nil, nil, nil, 0, 0)

	// Build the document tree:
	// { "app": "myservice", "debug": "true", "ports": ["8080", "8443"] }

	root := yaml.document_add_mapping(&document, nil, .BLOCK_MAPPING_STYLE)

	add_scalar :: proc(doc: ^yaml.document_t, value: string) -> c.int {
		return yaml.document_add_scalar(
			doc,
			nil,
			raw_data(value),
			c.int(len(value)),
			.ANY_SCALAR_STYLE,
		)
	}

	// "app": "myservice"
	key1 := add_scalar(&document, "app")
	val1 := add_scalar(&document, "myservice")
	yaml.document_append_mapping_pair(&document, root, key1, val1)

	// "debug": "true"
	key2 := add_scalar(&document, "debug")
	val2 := add_scalar(&document, "true")
	yaml.document_append_mapping_pair(&document, root, key2, val2)

	// "ports": ["8080", "8443"]
	key3 := add_scalar(&document, "ports")
	seq := yaml.document_add_sequence(&document, nil, .BLOCK_SEQUENCE_STYLE)
	item1 := add_scalar(&document, "8080")
	item2 := add_scalar(&document, "8443")
	yaml.document_append_sequence_item(&document, seq, item1)
	yaml.document_append_sequence_item(&document, seq, item2)
	yaml.document_append_mapping_pair(&document, root, key3, seq)

	// Dump the document
	yaml.emitter_dump(&emitter, &document)
	// document is deleted by emitter_dump

	// Close the emitter stream
	yaml.emitter_close(&emitter)

	result := string(output_buffer[:written])
	fmt.println("--- Generated YAML ---")
	fmt.print(result)
}
