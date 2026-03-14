// Example: Load a YAML document and walk the node tree
package loader_example

import "core:c"
import "core:fmt"
import yaml "../.."

main :: proc() {
	input := `database:
  host: db.example.com
  port: 5432
  credentials:
    user: admin
    password: secret
  replicas:
    - replica1.example.com
    - replica2.example.com
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

	document: yaml.document_t
	if yaml.parser_load(&parser, &document) == 0 {
		fmt.eprintfln("Load error: %s", parser.problem)
		return
	}
	defer yaml.document_delete(&document)

	root := yaml.document_get_root_node(&document)
	if root == nil {
		fmt.println("Empty document")
		return
	}

	print_node(&document, root, 0)
}

print_node :: proc(doc: ^yaml.document_t, node: ^yaml.node_t, indent: int) {
	do_indent :: proc(n: int) {
		for _ in 0 ..< n {
			fmt.print("  ")
		}
	}

	#partial switch node.type {
	case .SCALAR_NODE:
		value := string(node.data.scalar.value[:node.data.scalar.length])
		fmt.printfln("\"%s\"", value)

	case .SEQUENCE_NODE:
		fmt.println("[sequence]")
		items := node.data.sequence.items
		count := (uintptr(items.end) - uintptr(items.start)) / size_of(yaml.node_item_t)
		for i in 0 ..< count {
			child := yaml.document_get_node(doc, items.start[i])
			if child != nil {
				do_indent(indent + 1)
				fmt.printf("- ")
				print_node(doc, child, indent + 2)
			}
		}

	case .MAPPING_NODE:
		fmt.println("{mapping}")
		pairs := node.data.mapping.pairs
		count := (uintptr(pairs.end) - uintptr(pairs.start)) / size_of(yaml.node_pair_t)
		for i in 0 ..< count {
			pair := pairs.start[i]
			key_node := yaml.document_get_node(doc, pair.key)
			val_node := yaml.document_get_node(doc, pair.value)
			if key_node != nil && val_node != nil {
				key_str := string(key_node.data.scalar.value[:key_node.data.scalar.length])
				do_indent(indent + 1)
				fmt.printf("%s: ", key_str)
				print_node(doc, val_node, indent + 1)
			}
		}
	}
}
