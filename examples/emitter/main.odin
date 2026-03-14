// Example: Construct YAML output using the event-based emitter API
package emitter_example

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

	event: yaml.event_t

	// Stream start
	yaml.stream_start_event_initialize(&event, .UTF8_ENCODING)
	yaml.emitter_emit(&emitter, &event)

	// Document start
	yaml.document_start_event_initialize(&event, nil, nil, nil, 0)
	yaml.emitter_emit(&emitter, &event)

	// Root mapping
	yaml.mapping_start_event_initialize(&event, nil, nil, 1, .BLOCK_MAPPING_STYLE)
	yaml.emitter_emit(&emitter, &event)

	emit_scalar :: proc(emitter: ^yaml.emitter_t, event: ^yaml.event_t, value: string) {
		yaml.scalar_event_initialize(
			event,
			nil, nil,
			raw_data(value),
			c.int(len(value)),
			1, 1,
			.ANY_SCALAR_STYLE,
		)
		yaml.emitter_emit(emitter, event)
	}

	// "name": "odin-libyaml"
	emit_scalar(&emitter, &event, "name")
	emit_scalar(&emitter, &event, "odin-libyaml")

	// "version": "0.1.0"
	emit_scalar(&emitter, &event, "version")
	emit_scalar(&emitter, &event, "0.1.0")

	// "authors": [...]
	emit_scalar(&emitter, &event, "authors")
	yaml.sequence_start_event_initialize(&event, nil, nil, 1, .BLOCK_SEQUENCE_STYLE)
	yaml.emitter_emit(&emitter, &event)
	emit_scalar(&emitter, &event, "Alice")
	emit_scalar(&emitter, &event, "Bob")
	yaml.sequence_end_event_initialize(&event)
	yaml.emitter_emit(&emitter, &event)

	// End mapping
	yaml.mapping_end_event_initialize(&event)
	yaml.emitter_emit(&emitter, &event)

	// Document end
	yaml.document_end_event_initialize(&event, 0)
	yaml.emitter_emit(&emitter, &event)

	// Stream end
	yaml.stream_end_event_initialize(&event)
	yaml.emitter_emit(&emitter, &event)

	result := string(output_buffer[:written])
	fmt.println("--- Generated YAML ---")
	fmt.print(result)
}
