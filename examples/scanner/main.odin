// Example: Tokenize a YAML string using the scanner API
package scanner_example

import "core:c"
import "core:fmt"
import yaml "../.."

main :: proc() {
	input := `name: Alice
age: 30
tags:
  - developer
  - gopher
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

	token: yaml.token_t
	for {
		if yaml.parser_scan(&parser, &token) == 0 {
			fmt.eprintfln("Scanner error: %s", parser.problem)
			return
		}

		#partial switch token.type {
		case .STREAM_START_TOKEN:
			fmt.println("STREAM-START")
		case .STREAM_END_TOKEN:
			fmt.println("STREAM-END")
		case .KEY_TOKEN:
			fmt.print("KEY ")
		case .VALUE_TOKEN:
			fmt.print("VALUE ")
		case .BLOCK_MAPPING_START_TOKEN:
			fmt.println("BLOCK-MAPPING-START")
		case .BLOCK_SEQUENCE_START_TOKEN:
			fmt.println("BLOCK-SEQUENCE-START")
		case .BLOCK_ENTRY_TOKEN:
			fmt.print("BLOCK-ENTRY ")
		case .BLOCK_END_TOKEN:
			fmt.println("BLOCK-END")
		case .SCALAR_TOKEN:
			value := string(token.data.scalar.value[:token.data.scalar.length])
			fmt.printfln("SCALAR \"%s\"", value)
		case:
			fmt.printfln("TOKEN(%v)", token.type)
		}

		done := token.type == .STREAM_END_TOKEN
		yaml.token_delete(&token)
		if done do break
	}
}
