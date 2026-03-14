// Example: Parse a YAML string using the event-based parser API
package parser_example

import "core:c"
import "core:fmt"
import yaml "../.."

main :: proc() {
	input := `---
server:
  host: localhost
  port: 8080
  features:
    - logging
    - metrics
...
`
	parser: yaml.parser_t
	if yaml.parser_initialize(&parser) == 0 {
		fmt.eprintln("Failed to initialize parser")
		return
	}
	defer yaml.parser_delete(&parser)

	yaml.parser_set_input_string(
		&parser,
		raw_data(input),
		len(input),
	)

	indent := 0
	event: yaml.event_t
	for {
		if yaml.parser_parse(&parser, &event) == 0 {
			fmt.eprintfln("Parse error: %s", parser.problem)
			return
		}

		#partial switch event.type {
		case .STREAM_START_EVENT:
			print_indent(indent)
			fmt.println("STREAM-START")
			indent += 1
		case .STREAM_END_EVENT:
			indent -= 1
			print_indent(indent)
			fmt.println("STREAM-END")
		case .DOCUMENT_START_EVENT:
			print_indent(indent)
			fmt.println("DOCUMENT-START")
			indent += 1
		case .DOCUMENT_END_EVENT:
			indent -= 1
			print_indent(indent)
			fmt.println("DOCUMENT-END")
		case .MAPPING_START_EVENT:
			print_indent(indent)
			fmt.println("MAPPING-START")
			indent += 1
		case .MAPPING_END_EVENT:
			indent -= 1
			print_indent(indent)
			fmt.println("MAPPING-END")
		case .SEQUENCE_START_EVENT:
			print_indent(indent)
			fmt.println("SEQUENCE-START")
			indent += 1
		case .SEQUENCE_END_EVENT:
			indent -= 1
			print_indent(indent)
			fmt.println("SEQUENCE-END")
		case .SCALAR_EVENT:
			value := string(event.data.scalar.value[:event.data.scalar.length])
			print_indent(indent)
			fmt.printfln("SCALAR \"%s\"", value)
		case .ALIAS_EVENT:
			print_indent(indent)
			fmt.printfln("ALIAS *%s", event.data.alias.anchor)
		}

		done := event.type == .STREAM_END_EVENT
		yaml.event_delete(&event)
		if done do break
	}
}

print_indent :: proc(level: int) {
	for _ in 0 ..< level {
		fmt.print("  ")
	}
}
