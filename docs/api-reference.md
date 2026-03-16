# odin-libyaml API Reference

Odin bindings for [libyaml](https://pyyaml.org/wiki/LibYAML) 0.2.5 — a C library for parsing and emitting YAML.

Package name: `yaml`

```odin
import yaml "path/to/odin-libyaml"
```

## Table of Contents

- [Build Configuration](#build-configuration)
- [Version](#version)
- [Basic Types](#basic-types)
- [Scanner (Tokenizer)](#scanner-tokenizer)
- [Parser (Event-Based)](#parser-event-based)
- [Loader (Document API)](#loader-document-api)
- [Emitter (Event-Based Output)](#emitter-event-based-output)
- [Dumper (Document-Based Output)](#dumper-document-based-output)
- [Error Handling](#error-handling)
- [High-Level Unmarshal API](#high-level-unmarshal-api)
- [Custom Unmarshalers](#custom-unmarshalers)

---

## Build Configuration

By default the binding links against the static library. To use the shared library instead, set the `LIBYAML_SHARED` config:

```odin
import yaml "odin-libyaml" // static link (default)
```

```sh
# To use shared library
odin run . -define:LIBYAML_SHARED=true
```

Library files are expected in:
- macOS: `macos/libyaml.a` (static) or `macos/libyaml.dylib` (shared)
- Windows: `windows/libyaml.lib` (static) or `windows/libyaml.dll` (shared)

---

## Version

### `get_version_string`

Returns the libyaml version as a C string.

```
get_version_string :: proc() -> cstring
```

**Returns:** A null-terminated version string (e.g. `"0.2.5"`).

### `get_version`

Retrieves the version as individual major/minor/patch integers.

```
get_version :: proc(major: ^c.int, minor: ^c.int, patch: ^c.int)
```

| Parameter | Type | Description |
|-----------|------|-------------|
| `major` | `^c.int` | Receives major version number |
| `minor` | `^c.int` | Receives minor version number |
| `patch` | `^c.int` | Receives patch version number |

**Sample:**

```odin
import "core:c"
import "core:fmt"
import yaml "../.."

main :: proc() {
    fmt.printfln("libyaml %s", yaml.get_version_string())

    major, minor, patch: c.int
    yaml.get_version(&major, &minor, &patch)
    fmt.printfln("%d.%d.%d", major, minor, patch)
}
```

**Output:**

```
libyaml 0.2.5
0.2.5
```

---

## Basic Types

### `char_t`

```
char_t :: c.uchar
```

The byte type used by libyaml for YAML content (UTF-8 encoded).

### `encoding_t`

```
encoding_t :: enum c.int {
    ANY_ENCODING     = 0,
    UTF8_ENCODING    = 1,
    UTF16LE_ENCODING = 2,
    UTF16BE_ENCODING = 3,
}
```

### `break_t`

Line break style for the emitter.

```
break_t :: enum c.int {
    ANY_BREAK  = 0,
    CR_BREAK   = 1,  // \r
    LN_BREAK   = 2,  // \n
    CRLN_BREAK = 3,  // \r\n
}
```

### `error_type_t`

```
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
```

### `mark_t`

A position in the YAML input.

```
mark_t :: struct {
    index:  c.size_t,  // byte offset from the beginning
    line:   c.size_t,  // 0-based line number
    column: c.size_t,  // 0-based column number
}
```

### `version_directive_t`

```
version_directive_t :: struct {
    major: c.int,
    minor: c.int,
}
```

### `tag_directive_t`

```
tag_directive_t :: struct {
    handle: [^]char_t,
    prefix: [^]char_t,
}
```

### Style Enums

```
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
    BLOCK_SEQUENCE_STYLE = 1,  // - item
    FLOW_SEQUENCE_STYLE  = 2,  // [item, item]
}

mapping_style_t :: enum c.int {
    ANY_MAPPING_STYLE   = 0,
    BLOCK_MAPPING_STYLE = 1,  // key: value
    FLOW_MAPPING_STYLE  = 2,  // {key: value}
}
```

---

## Scanner (Tokenizer)

The scanner breaks YAML input into tokens. This is the lowest-level parsing API.

### Token Types

```
token_type_t :: enum c.int {
    NO_TOKEN, STREAM_START_TOKEN, STREAM_END_TOKEN,
    VERSION_DIRECTIVE_TOKEN, TAG_DIRECTIVE_TOKEN,
    DOCUMENT_START_TOKEN, DOCUMENT_END_TOKEN,
    BLOCK_SEQUENCE_START_TOKEN, BLOCK_MAPPING_START_TOKEN, BLOCK_END_TOKEN,
    FLOW_SEQUENCE_START_TOKEN, FLOW_SEQUENCE_END_TOKEN,
    FLOW_MAPPING_START_TOKEN, FLOW_MAPPING_END_TOKEN,
    BLOCK_ENTRY_TOKEN, FLOW_ENTRY_TOKEN,
    KEY_TOKEN, VALUE_TOKEN,
    ALIAS_TOKEN, ANCHOR_TOKEN, TAG_TOKEN, SCALAR_TOKEN,
}
```

### `token_t`

```
token_t :: struct {
    type: token_type_t,
    data: struct #raw_union {
        stream_start: struct { encoding: encoding_t },
        alias:        struct { value: [^]char_t },
        anchor:       struct { value: [^]char_t },
        tag:          struct { handle: [^]char_t, suffix: [^]char_t },
        scalar:       struct { value: [^]char_t, length: c.size_t, style: scalar_style_t },
        version_directive: struct { major: c.int, minor: c.int },
        tag_directive:     struct { handle: [^]char_t, prefix: [^]char_t },
    },
    start_mark: mark_t,
    end_mark:   mark_t,
}
```

### `parser_scan`

Scans the next token from the input.

```
parser_scan :: proc(parser: ^parser_t, token: ^token_t) -> c.int
```

| Parameter | Type | Description |
|-----------|------|-------------|
| `parser` | `^parser_t` | An initialized parser with input set |
| `token` | `^token_t` | Receives the scanned token |

**Returns:** `1` on success, `0` on error.

### `token_delete`

Frees resources associated with a token.

```
token_delete :: proc(token: ^token_t)
```

### Sample: Tokenize a YAML string

```odin
import "core:fmt"
import yaml "../.."

main :: proc() {
    input := `name: Alice
age: 30
`
    parser: yaml.parser_t
    assert(yaml.parser_initialize(&parser) != 0)
    defer yaml.parser_delete(&parser)

    yaml.parser_set_input_string(&parser, raw_data(input), len(input))

    token: yaml.token_t
    for {
        assert(yaml.parser_scan(&parser, &token) != 0)

        #partial switch token.type {
        case .SCALAR_TOKEN:
            value := string(token.data.scalar.value[:token.data.scalar.length])
            fmt.printfln("SCALAR \"%s\"", value)
        case .KEY_TOKEN:
            fmt.println("KEY")
        case .VALUE_TOKEN:
            fmt.println("VALUE")
        case:
            fmt.printfln("%v", token.type)
        }

        done := token.type == .STREAM_END_TOKEN
        yaml.token_delete(&token)
        if done do break
    }
}
```

**Output:**

```
STREAM_START_TOKEN
BLOCK_MAPPING_START_TOKEN
KEY
SCALAR "name"
VALUE
SCALAR "Alice"
KEY
SCALAR "age"
VALUE
SCALAR "30"
BLOCK_END_TOKEN
STREAM_END_TOKEN
```

---

## Parser (Event-Based)

The parser produces a stream of events representing the YAML structure. This is the recommended API for most use cases.

### Event Types

```
event_type_t :: enum c.int {
    NO_EVENT, STREAM_START_EVENT, STREAM_END_EVENT,
    DOCUMENT_START_EVENT, DOCUMENT_END_EVENT,
    ALIAS_EVENT, SCALAR_EVENT,
    SEQUENCE_START_EVENT, SEQUENCE_END_EVENT,
    MAPPING_START_EVENT, MAPPING_END_EVENT,
}
```

### `event_t`

```
event_t :: struct {
    type: event_type_t,
    data: struct #raw_union {
        stream_start:   struct { encoding: encoding_t },
        document_start: struct {
            version_directive: ^version_directive_t,
            tag_directives: struct { start, end: [^]tag_directive_t },
            implicit: c.int,
        },
        document_end: struct { implicit: c.int },
        alias:        struct { anchor: [^]char_t },
        scalar: struct {
            anchor, tag, value: [^]char_t,
            length: c.size_t,
            plain_implicit, quoted_implicit: c.int,
            style: scalar_style_t,
        },
        sequence_start: struct {
            anchor, tag: [^]char_t,
            implicit: c.int, style: sequence_style_t,
        },
        mapping_start: struct {
            anchor, tag: [^]char_t,
            implicit: c.int, style: mapping_style_t,
        },
    },
    start_mark: mark_t,
    end_mark:   mark_t,
}
```

### Parser Functions

#### `parser_initialize`

Creates a new parser. Must be followed by `parser_delete` when done.

```
parser_initialize :: proc(parser: ^parser_t) -> c.int
```

**Returns:** `1` on success, `0` on failure (memory allocation).

#### `parser_delete`

Destroys a parser and frees its resources.

```
parser_delete :: proc(parser: ^parser_t)
```

#### `parser_set_input_string`

Sets a byte string as the parser input.

```
parser_set_input_string :: proc(parser: ^parser_t, input: [^]c.uchar, size: c.size_t)
```

| Parameter | Type | Description |
|-----------|------|-------------|
| `parser` | `^parser_t` | An initialized parser |
| `input` | `[^]c.uchar` | Pointer to UTF-8 YAML content |
| `size` | `c.size_t` | Length in bytes |

#### `parser_set_input_file`

Sets a C FILE handle as the parser input.

```
parser_set_input_file :: proc(parser: ^parser_t, file: ^libc.FILE)
```

#### `parser_set_input`

Sets a custom read handler as the parser input.

```
parser_set_input :: proc(parser: ^parser_t, handler: read_handler_t, data: rawptr)
```

The handler type:

```
read_handler_t :: #type proc "c" (
    data: rawptr, buffer: [^]c.uchar, size: c.size_t, size_read: ^c.size_t,
) -> c.int
```

#### `parser_set_encoding`

Forces a specific input encoding.

```
parser_set_encoding :: proc(parser: ^parser_t, encoding: encoding_t)
```

#### `parser_parse`

Parses the next event from the input.

```
parser_parse :: proc(parser: ^parser_t, event: ^event_t) -> c.int
```

**Returns:** `1` on success, `0` on error. Check `parser.error` and `parser.problem` on failure.

#### `event_delete`

Frees resources associated with an event.

```
event_delete :: proc(event: ^event_t)
```

### Sample: Parse YAML events

```odin
import "core:fmt"
import yaml "../.."

main :: proc() {
    input := `server:
  host: localhost
  port: 8080
`
    parser: yaml.parser_t
    assert(yaml.parser_initialize(&parser) != 0)
    defer yaml.parser_delete(&parser)

    yaml.parser_set_input_string(&parser, raw_data(input), len(input))

    event: yaml.event_t
    for {
        assert(yaml.parser_parse(&parser, &event) != 0)

        #partial switch event.type {
        case .SCALAR_EVENT:
            value := string(event.data.scalar.value[:event.data.scalar.length])
            fmt.printfln("SCALAR \"%s\"", value)
        case .MAPPING_START_EVENT:
            fmt.println("MAPPING-START")
        case .MAPPING_END_EVENT:
            fmt.println("MAPPING-END")
        case .DOCUMENT_START_EVENT:
            fmt.println("DOCUMENT-START")
        case .DOCUMENT_END_EVENT:
            fmt.println("DOCUMENT-END")
        case .STREAM_START_EVENT:
            fmt.println("STREAM-START")
        case .STREAM_END_EVENT:
            fmt.println("STREAM-END")
        }

        done := event.type == .STREAM_END_EVENT
        yaml.event_delete(&event)
        if done do break
    }
}
```

**Output:**

```
STREAM-START
DOCUMENT-START
MAPPING-START
SCALAR "server"
MAPPING-START
SCALAR "host"
SCALAR "localhost"
SCALAR "port"
SCALAR "8080"
MAPPING-END
MAPPING-END
DOCUMENT-END
STREAM-END
```

---

## Loader (Document API)

The loader parses YAML into an in-memory document tree of nodes. Use this when you need random access to the YAML structure.

### Node Types

```
node_type_t :: enum c.int {
    NO_NODE       = 0,
    SCALAR_NODE   = 1,
    SEQUENCE_NODE = 2,
    MAPPING_NODE  = 3,
}
```

### `node_t`

```
node_t :: struct {
    type: node_type_t,
    tag:  [^]char_t,
    data: struct #raw_union {
        scalar: struct {
            value: [^]char_t, length: c.size_t, style: scalar_style_t,
        },
        sequence: struct {
            items: struct { start, end, top: [^]node_item_t },
            style: sequence_style_t,
        },
        mapping: struct {
            pairs: struct { start, end, top: [^]node_pair_t },
            style: mapping_style_t,
        },
    },
    start_mark: mark_t,
    end_mark:   mark_t,
}
```

Where:

```
node_item_t :: c.int          // 1-based node index
node_pair_t :: struct {
    key:   c.int,             // 1-based node index
    value: c.int,             // 1-based node index
}
```

### `document_t`

```
document_t :: struct {
    nodes: struct { start, end, top: [^]node_t },
    version_directive: ^version_directive_t,
    tag_directives: struct { start, end: [^]tag_directive_t },
    start_implicit, end_implicit: c.int,
    start_mark, end_mark: mark_t,
}
```

### Loader Functions

#### `parser_load`

Loads the next YAML document from the parser into a document object.

```
parser_load :: proc(parser: ^parser_t, document: ^document_t) -> c.int
```

| Parameter | Type | Description |
|-----------|------|-------------|
| `parser` | `^parser_t` | An initialized parser with input set |
| `document` | `^document_t` | Receives the loaded document |

**Returns:** `1` on success, `0` on error.

#### `document_delete`

Frees a document and all its nodes.

```
document_delete :: proc(document: ^document_t)
```

#### `document_get_root_node`

Returns the root node of the document.

```
document_get_root_node :: proc(document: ^document_t) -> ^node_t
```

**Returns:** Pointer to the root node, or `nil` if the document is empty.

#### `document_get_node`

Returns a node by its 1-based index.

```
document_get_node :: proc(document: ^document_t, index: c.int) -> ^node_t
```

| Parameter | Type | Description |
|-----------|------|-------------|
| `document` | `^document_t` | The document |
| `index` | `c.int` | 1-based node index |

**Returns:** Pointer to the node, or `nil` if the index is invalid.

### Sample: Load a document and walk the tree

```odin
import "core:c"
import "core:fmt"
import yaml "../.."

main :: proc() {
    input := `fruits:
  - apple
  - banana
  - cherry
`
    parser: yaml.parser_t
    assert(yaml.parser_initialize(&parser) != 0)
    defer yaml.parser_delete(&parser)

    yaml.parser_set_input_string(&parser, raw_data(input), len(input))

    document: yaml.document_t
    assert(yaml.parser_load(&parser, &document) != 0)
    defer yaml.document_delete(&document)

    root := yaml.document_get_root_node(&document)
    if root == nil {
        fmt.println("Empty document")
        return
    }

    // root is a mapping — iterate its key/value pairs
    assert(root.type == .MAPPING_NODE)
    pairs := root.data.mapping.pairs
    count := (uintptr(pairs.end) - uintptr(pairs.start)) / size_of(yaml.node_pair_t)

    for i in 0 ..< count {
        pair := pairs.start[i]
        key := yaml.document_get_node(&document, pair.key)
        val := yaml.document_get_node(&document, pair.value)

        key_str := string(key.data.scalar.value[:key.data.scalar.length])
        fmt.printfln("%s:", key_str)

        // val is a sequence — iterate its items
        if val.type == .SEQUENCE_NODE {
            items := val.data.sequence.items
            n := (uintptr(items.end) - uintptr(items.start)) / size_of(yaml.node_item_t)
            for j in 0 ..< n {
                child := yaml.document_get_node(&document, items.start[j])
                v := string(child.data.scalar.value[:child.data.scalar.length])
                fmt.printfln("  - %s", v)
            }
        }
    }
}
```

**Output:**

```
fruits:
  - apple
  - banana
  - cherry
```

---

## Emitter (Event-Based Output)

The emitter converts a stream of events into YAML text. This gives you fine-grained control over the output.

### Emitter Functions

#### `emitter_initialize`

Creates a new emitter. Must be followed by `emitter_delete`.

```
emitter_initialize :: proc(emitter: ^emitter_t) -> c.int
```

**Returns:** `1` on success, `0` on failure.

#### `emitter_delete`

Destroys an emitter.

```
emitter_delete :: proc(emitter: ^emitter_t)
```

#### `emitter_set_output_string`

Sets a byte buffer as the emitter output destination.

```
emitter_set_output_string :: proc(
    emitter: ^emitter_t,
    output: [^]c.uchar,
    size: c.size_t,
    size_written: ^c.size_t,
)
```

| Parameter | Type | Description |
|-----------|------|-------------|
| `emitter` | `^emitter_t` | An initialized emitter |
| `output` | `[^]c.uchar` | Output buffer |
| `size` | `c.size_t` | Buffer capacity in bytes |
| `size_written` | `^c.size_t` | Receives the number of bytes written |

#### `emitter_set_output_file`

Sets a C FILE handle as the emitter output.

```
emitter_set_output_file :: proc(emitter: ^emitter_t, file: ^libc.FILE)
```

#### `emitter_set_output`

Sets a custom write handler as the emitter output.

```
emitter_set_output :: proc(emitter: ^emitter_t, handler: write_handler_t, data: rawptr)
```

The handler type:

```
write_handler_t :: #type proc "c" (data: rawptr, buffer: [^]c.uchar, size: c.size_t) -> c.int
```

#### Output Options

```
emitter_set_encoding  :: proc(emitter: ^emitter_t, encoding: encoding_t)
emitter_set_canonical :: proc(emitter: ^emitter_t, canonical: c.int)
emitter_set_indent    :: proc(emitter: ^emitter_t, indent: c.int)
emitter_set_width     :: proc(emitter: ^emitter_t, width: c.int)
emitter_set_unicode   :: proc(emitter: ^emitter_t, unicode: c.int)
emitter_set_break     :: proc(emitter: ^emitter_t, line_break: break_t)
```

| Function | Description |
|----------|-------------|
| `set_encoding` | Force output encoding (default: UTF-8) |
| `set_canonical` | `1` to emit canonical YAML with explicit tags |
| `set_indent` | Indentation width (2–9, default 2) |
| `set_width` | Preferred line width (default 80, `-1` for unlimited) |
| `set_unicode` | `1` to allow non-ASCII characters unescaped |
| `set_break` | Line break style |

#### `emitter_emit`

Emits an event. The event is consumed and must not be reused.

```
emitter_emit :: proc(emitter: ^emitter_t, event: ^event_t) -> c.int
```

**Returns:** `1` on success, `0` on error.

#### `emitter_flush`

Flushes the accumulated output.

```
emitter_flush :: proc(emitter: ^emitter_t) -> c.int
```

### Event Initializers

These functions prepare an `event_t` to be passed to `emitter_emit`. All return `1` on success, `0` on error.

```
stream_start_event_initialize   :: proc(event: ^event_t, encoding: encoding_t) -> c.int
stream_end_event_initialize     :: proc(event: ^event_t) -> c.int

document_start_event_initialize :: proc(
    event: ^event_t,
    version_directive: ^version_directive_t,
    tag_directives_start: [^]tag_directive_t,
    tag_directives_end: [^]tag_directive_t,
    implicit: c.int,
) -> c.int
document_end_event_initialize   :: proc(event: ^event_t, implicit: c.int) -> c.int

alias_event_initialize          :: proc(event: ^event_t, anchor: [^]char_t) -> c.int

scalar_event_initialize :: proc(
    event: ^event_t,
    anchor: [^]char_t,       // nil for no anchor
    tag: [^]char_t,          // nil for auto-tag
    value: [^]char_t,
    length: c.int,
    plain_implicit: c.int,   // 1 to allow plain style
    quoted_implicit: c.int,  // 1 to allow quoted style
    style: scalar_style_t,
) -> c.int

sequence_start_event_initialize :: proc(
    event: ^event_t,
    anchor: [^]char_t,
    tag: [^]char_t,
    implicit: c.int,
    style: sequence_style_t,
) -> c.int
sequence_end_event_initialize   :: proc(event: ^event_t) -> c.int

mapping_start_event_initialize  :: proc(
    event: ^event_t,
    anchor: [^]char_t,
    tag: [^]char_t,
    implicit: c.int,
    style: mapping_style_t,
) -> c.int
mapping_end_event_initialize    :: proc(event: ^event_t) -> c.int
```

### Sample: Emit a YAML document to a string buffer

```odin
import "core:c"
import "core:fmt"
import yaml "../.."

BUFFER_SIZE :: 16 * 1024

main :: proc() {
    buf: [BUFFER_SIZE]c.uchar
    written: c.size_t

    emitter: yaml.emitter_t
    assert(yaml.emitter_initialize(&emitter) != 0)
    defer yaml.emitter_delete(&emitter)

    yaml.emitter_set_output_string(&emitter, raw_data(buf[:]), BUFFER_SIZE, &written)
    yaml.emitter_set_unicode(&emitter, 1)

    event: yaml.event_t

    emit_scalar :: proc(e: ^yaml.emitter_t, ev: ^yaml.event_t, val: string) {
        yaml.scalar_event_initialize(ev, nil, nil, raw_data(val), c.int(len(val)), 1, 1, .ANY_SCALAR_STYLE)
        yaml.emitter_emit(e, ev)
    }

    // stream start → document start → mapping { key: value } → document end → stream end
    yaml.stream_start_event_initialize(&event, .UTF8_ENCODING)
    yaml.emitter_emit(&emitter, &event)

    yaml.document_start_event_initialize(&event, nil, nil, nil, 0)
    yaml.emitter_emit(&emitter, &event)

    yaml.mapping_start_event_initialize(&event, nil, nil, 1, .BLOCK_MAPPING_STYLE)
    yaml.emitter_emit(&emitter, &event)

    emit_scalar(&emitter, &event, "greeting")
    emit_scalar(&emitter, &event, "Hello, YAML!")

    yaml.mapping_end_event_initialize(&event)
    yaml.emitter_emit(&emitter, &event)

    yaml.document_end_event_initialize(&event, 0)
    yaml.emitter_emit(&emitter, &event)

    yaml.stream_end_event_initialize(&event)
    yaml.emitter_emit(&emitter, &event)

    fmt.print(string(buf[:written]))
}
```

**Output:**

```yaml
---
greeting: Hello, YAML!
...
```

---

## Dumper (Document-Based Output)

The dumper API builds a document tree in memory then serializes it in one call. This is simpler than the event-based emitter when you can construct the entire document before output.

### Document Builder Functions

#### `document_initialize`

Creates an empty document.

```
document_initialize :: proc(
    document: ^document_t,
    version_directive: ^version_directive_t,
    tag_directives_start: [^]tag_directive_t,
    tag_directives_end: [^]tag_directive_t,
    start_implicit: c.int,
    end_implicit: c.int,
) -> c.int
```

All pointer parameters can be `nil` for defaults. `start_implicit` / `end_implicit` control whether `---` / `...` markers are emitted (`1` = suppress).

**Returns:** `1` on success.

#### `document_add_scalar`

Adds a scalar node to the document.

```
document_add_scalar :: proc(
    document: ^document_t,
    tag: [^]char_t,         // nil for default (tag:yaml.org,2002:str)
    value: [^]char_t,
    length: c.int,
    style: scalar_style_t,
) -> c.int
```

**Returns:** The 1-based node index, or `0` on error.

#### `document_add_sequence`

Adds an empty sequence node.

```
document_add_sequence :: proc(
    document: ^document_t,
    tag: [^]char_t,        // nil for default (tag:yaml.org,2002:seq)
    style: sequence_style_t,
) -> c.int
```

**Returns:** The 1-based node index, or `0` on error.

#### `document_add_mapping`

Adds an empty mapping node.

```
document_add_mapping :: proc(
    document: ^document_t,
    tag: [^]char_t,        // nil for default (tag:yaml.org,2002:map)
    style: mapping_style_t,
) -> c.int
```

**Returns:** The 1-based node index, or `0` on error.

#### `document_append_sequence_item`

Appends an item to a sequence node.

```
document_append_sequence_item :: proc(
    document: ^document_t,
    sequence: c.int,       // sequence node index
    item: c.int,           // item node index
) -> c.int
```

#### `document_append_mapping_pair`

Appends a key-value pair to a mapping node.

```
document_append_mapping_pair :: proc(
    document: ^document_t,
    mapping: c.int,        // mapping node index
    key: c.int,            // key node index
    value: c.int,          // value node index
) -> c.int
```

### Dumper Functions

#### `emitter_open`

Opens the emitter stream (emits STREAM-START). Required before `emitter_dump`.

```
emitter_open :: proc(emitter: ^emitter_t) -> c.int
```

#### `emitter_dump`

Serializes a document to the emitter output. **The document is consumed** — `document_delete` is called internally.

```
emitter_dump :: proc(emitter: ^emitter_t, document: ^document_t) -> c.int
```

#### `emitter_close`

Closes the emitter stream (emits STREAM-END).

```
emitter_close :: proc(emitter: ^emitter_t) -> c.int
```

### Sample: Build and dump a document

```odin
import "core:c"
import "core:fmt"
import yaml "../.."

BUFFER_SIZE :: 16 * 1024

main :: proc() {
    buf: [BUFFER_SIZE]c.uchar
    written: c.size_t

    emitter: yaml.emitter_t
    assert(yaml.emitter_initialize(&emitter) != 0)
    defer yaml.emitter_delete(&emitter)

    yaml.emitter_set_output_string(&emitter, raw_data(buf[:]), BUFFER_SIZE, &written)
    yaml.emitter_open(&emitter)

    document: yaml.document_t
    yaml.document_initialize(&document, nil, nil, nil, 0, 0)

    add_scalar :: proc(doc: ^yaml.document_t, val: string) -> c.int {
        return yaml.document_add_scalar(doc, nil, raw_data(val), c.int(len(val)), .ANY_SCALAR_STYLE)
    }

    // Build: { app: myservice, ports: [8080, 8443] }
    root := yaml.document_add_mapping(&document, nil, .BLOCK_MAPPING_STYLE)

    k1 := add_scalar(&document, "app")
    v1 := add_scalar(&document, "myservice")
    yaml.document_append_mapping_pair(&document, root, k1, v1)

    k2 := add_scalar(&document, "ports")
    seq := yaml.document_add_sequence(&document, nil, .FLOW_SEQUENCE_STYLE)
    yaml.document_append_sequence_item(&document, seq, add_scalar(&document, "8080"))
    yaml.document_append_sequence_item(&document, seq, add_scalar(&document, "8443"))
    yaml.document_append_mapping_pair(&document, root, k2, seq)

    // Dump (document is consumed here)
    yaml.emitter_dump(&emitter, &document)
    yaml.emitter_close(&emitter)

    fmt.print(string(buf[:written]))
}
```

**Output:**

```yaml
---
app: myservice
ports: [8080, 8443]
...
```

---

## Error Handling

All libyaml functions that can fail return `c.int`: `1` for success, `0` for failure.

On failure, the parser or emitter struct contains error details:

```odin
parser: yaml.parser_t
// ... after a failed call:
if parser.error != .NO_ERROR {
    fmt.eprintfln("Error type: %v", parser.error)
    fmt.eprintfln("Problem:    %s", parser.problem)
    fmt.eprintfln("Location:   line %d, column %d",
        parser.problem_mark.line + 1,
        parser.problem_mark.column + 1,
    )
}
```

For the emitter:

```odin
emitter: yaml.emitter_t
// ... after a failed call:
if emitter.error != .NO_ERROR {
    fmt.eprintfln("Error type: %v", emitter.error)
    fmt.eprintfln("Problem:    %s", emitter.problem)
}
```

### Error Types

| Value | Meaning |
|-------|---------|
| `NO_ERROR` | No error |
| `MEMORY_ERROR` | Memory allocation failed |
| `READER_ERROR` | Input read error or invalid encoding |
| `SCANNER_ERROR` | Invalid token in input |
| `PARSER_ERROR` | Invalid YAML structure |
| `COMPOSER_ERROR` | Invalid document structure (e.g. undefined alias) |
| `WRITER_ERROR` | Output write error |
| `EMITTER_ERROR` | Invalid event sequence for emitter |

### Sample: Handle parse errors

```odin
import "core:fmt"
import yaml "../.."

main :: proc() {
    // Invalid YAML: tab character in indentation
    input := "items:\n\t- bad indent\n"

    parser: yaml.parser_t
    assert(yaml.parser_initialize(&parser) != 0)
    defer yaml.parser_delete(&parser)

    yaml.parser_set_input_string(&parser, raw_data(input), len(input))

    event: yaml.event_t
    for {
        if yaml.parser_parse(&parser, &event) == 0 {
            fmt.eprintfln("Parse error at line %d, col %d: %s",
                parser.problem_mark.line + 1,
                parser.problem_mark.column + 1,
                parser.problem,
            )
            return
        }
        done := event.type == .STREAM_END_EVENT
        yaml.event_delete(&event)
        if done do break
    }
}
```

**Output:**

```
Parse error at line 2, col 0: found character that cannot start any token
```

---

## Tag Constants

The following YAML tag constants are available:

```
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
```

---

## Miscellaneous

### `set_max_nest_level`

Sets the maximum nesting depth for the parser. Default is 0 (unlimited).

```
set_max_nest_level :: proc(max: c.int)
```

### Common Patterns

**Convert `[^]char_t` to Odin `string`:**

```odin
// When length is known (e.g. from scalar.length):
value := string(node.data.scalar.value[:node.data.scalar.length])

// For null-terminated values (e.g. tag):
tag := string(cstring(raw_data(node.tag[:1])))  // not recommended
// Better: use transmute if you know it's null-terminated
```

**Pass an Odin `string` to libyaml:**

```odin
yaml.parser_set_input_string(&parser, raw_data(input), len(input))

yaml.scalar_event_initialize(&event, nil, nil, raw_data(value), c.int(len(value)), 1, 1, .ANY_SCALAR_STYLE)
```

**Iterate sequence items:**

```odin
items := node.data.sequence.items
count := (uintptr(items.end) - uintptr(items.start)) / size_of(yaml.node_item_t)
for i in 0 ..< count {
    child := yaml.document_get_node(&document, items.start[i])
    // ...
}
```

**Iterate mapping pairs:**

```odin
pairs := node.data.mapping.pairs
count := (uintptr(pairs.end) - uintptr(pairs.start)) / size_of(yaml.node_pair_t)
for i in 0 ..< count {
    pair := pairs.start[i]
    key := yaml.document_get_node(&document, pair.key)
    val := yaml.document_get_node(&document, pair.value)
    // ...
}
```

---

## High-Level Unmarshal API

The `unmarshal` family of functions decode YAML directly into Odin structs using reflection. This is the easiest way to consume YAML data.

### `unmarshal`

Decodes YAML bytes into a typed pointer.

```
unmarshal :: proc(data: []byte, ptr: ^$T, allocator := context.allocator) -> Unmarshal_Error
```

### `unmarshal_string`

Decodes a YAML string into a typed pointer.

```
unmarshal_string :: proc(data: string, ptr: ^$T, allocator := context.allocator) -> Unmarshal_Error
```

### `unmarshal_any`

Low-level version that accepts `any`. The value must be a pointer.

```
unmarshal_any :: proc(data: []byte, v: any, allocator := context.allocator) -> Unmarshal_Error
```

### Supported Types

| Odin Type | YAML Node Type | Notes |
|-----------|---------------|-------|
| `string`, `cstring` | Scalar | String is cloned via allocator |
| `bool`, `b8`..`b64` | Scalar | `true/false/yes/no/on/off` (case variants) |
| `int`, `i8`..`i128`, `u8`..`u128` | Scalar | Decimal, `0x` hex, `0o` octal, `0b` binary |
| `f16`..`f64` | Scalar | Also `.inf`, `-.inf`, `.nan` |
| `enum` | Scalar | Name match (exact then case-insensitive), or integer value |
| `struct` | Mapping | Fields matched by `yaml` struct tag or field name |
| `struct` | Sequence | Positional mapping: elements fill fields in declaration order |
| `[]T` (slice) | Sequence | Allocated via allocator |
| `[dynamic]T` | Sequence | Allocated via allocator |
| `[N]T` (fixed array) | Sequence | Fills up to N elements |
| `map[string]T` | Mapping | Keys and values decoded recursively |
| `^T` (pointer) | Any | Allocates and recurses; `null` → `nil` |
| `Maybe(T)` | Any | Sets the variant on non-null values |
| Multi-variant `union` | Any | Tries each variant in order |

### Struct Tags

Use the `yaml` struct tag to control field name mapping:

```odin
Config :: struct {
    api_key:     string `yaml:"api-key"`,     // maps to YAML key "api-key"
    internal_id: string `yaml:"-"`,           // ignored during unmarshal
    name:        string,                       // maps to YAML key "name"
}
```

### Error Types

```
Unmarshal_Error :: union {
    Unmarshal_Data_Error,       // .Invalid_Data, .Invalid_Parameter, .Non_Pointer_Parameter
    Unsupported_Type_Error,     // struct { id: typeid }
    Yaml_Parse_Error,           // struct { problem: string, line: int, column: int }
    Scalar_Conversion_Error,    // struct { value: string, target_type: typeid }
    runtime.Allocator_Error,
}
```

### Sample: Basic unmarshal

```odin
import "core:fmt"
import yaml "../.."

main :: proc() {
    Server :: struct {
        host: string,
        port: int,
    }
    Config :: struct {
        name:   string,
        debug:  bool,
        server: Server,
        tags:   []string,
    }

    input := `
name: my-app
debug: true
server:
  host: localhost
  port: 8080
tags:
  - web
  - api
`
    cfg: Config
    err := yaml.unmarshal_string(input, &cfg)
    if err != nil {
        fmt.eprintfln("Error: %v", err)
        return
    }

    fmt.printfln("Name:   %s", cfg.name)
    fmt.printfln("Debug:  %v", cfg.debug)
    fmt.printfln("Server: %s:%d", cfg.server.host, cfg.server.port)
    fmt.printfln("Tags:   %v", cfg.tags)
}
```

**Output:**

```
Name:   my-app
Debug:  true
Server: localhost:8080
Tags:   [web, api]
```

---

## Custom Unmarshalers

When the default reflection-based decoding is insufficient — for example, when a YAML scalar needs to be parsed into a complex struct, or a type accepts multiple YAML representations — you can register custom unmarshalers.

This follows the same `map[typeid]proc` global registry pattern used by `core:encoding/json`.

### Types

#### `Unmarshal_Context`

Context passed to custom unmarshaler procedures, providing access to the current YAML node and helpers.

```
Unmarshal_Context :: struct {
    doc:       ^document_t,
    node:      ^node_t,
    allocator: mem.Allocator,
}
```

#### `User_Unmarshaler`

The procedure signature for custom unmarshalers. `v` is an `any` pointing directly to the target data (not a pointer to a pointer).

```
User_Unmarshaler :: #type proc(ctx: Unmarshal_Context, v: any) -> Unmarshal_Error
```

#### `Register_User_Unmarshaler_Error`

```
Register_User_Unmarshaler_Error :: enum {
    None,                       // Success
    No_User_Unmarshaler,        // Registry not initialized (set_user_unmarshalers not called)
    Unmarshaler_Previously_Found, // Type already registered
}
```

### Registry Functions

#### `set_user_unmarshalers`

Initializes the custom unmarshaler registry. Pass `nil` to disable custom unmarshaling.

```
set_user_unmarshalers :: proc(m: ^map[typeid]User_Unmarshaler)
```

#### `register_user_unmarshaler`

Registers a custom unmarshaler for a specific type.

```
register_user_unmarshaler :: proc(id: typeid, unmarshaler: User_Unmarshaler) -> Register_User_Unmarshaler_Error
```

### Context Helper Functions

These functions are used inside custom unmarshalers to inspect nodes and delegate decoding.

#### `unmarshal_ctx_decode`

Delegates to the standard reflection-based decode for the current node. This skips the custom unmarshaler for the current type to avoid infinite recursion.

```
unmarshal_ctx_decode :: proc(ctx: Unmarshal_Context, target: any) -> Unmarshal_Error
```

#### `unmarshal_ctx_decode_node`

Decodes a specific node into a target value. Custom unmarshalers for the target type **will** be invoked.

```
unmarshal_ctx_decode_node :: proc(ctx: Unmarshal_Context, node: ^node_t, target: any) -> Unmarshal_Error
```

#### `unmarshal_ctx_node_type`

Returns the type of the current node.

```
unmarshal_ctx_node_type :: proc(ctx: Unmarshal_Context) -> node_type_t
```

#### `unmarshal_ctx_node_value`

Returns the scalar value of the current node as a string. Returns `""` if the node is not a scalar.

```
unmarshal_ctx_node_value :: proc(ctx: Unmarshal_Context) -> string
```

#### `unmarshal_ctx_mapping_pairs`

Returns the key-value pairs of a mapping node as a slice.

```
unmarshal_ctx_mapping_pairs :: proc(ctx: Unmarshal_Context) -> []node_pair_t
```

#### `unmarshal_ctx_sequence_items`

Returns the items of a sequence node as a slice.

```
unmarshal_ctx_sequence_items :: proc(ctx: Unmarshal_Context) -> []node_item_t
```

#### `unmarshal_ctx_get_node`

Retrieves a node by its ID (1-based index) from the document.

```
unmarshal_ctx_get_node :: proc(ctx: Unmarshal_Context, id: node_item_t) -> ^node_t
```

### Execution Order

When `unmarshal_node` processes a value:

1. **Custom unmarshaler check** — if a `User_Unmarshaler` is registered for the type, it is called immediately
2. **Pointer handling** — allocates and recurses into the pointed-to type
3. **Union handling** — tries each variant (including `Maybe(T)`)
4. **Node type dispatch** — scalar / mapping / sequence processing via reflection

### Sample: Color type with hex string and mapping support

```odin
import "core:fmt"
import "core:strconv"
import yaml "../.."

Color :: struct {
    r: u8,
    g: u8,
    b: u8,
}

color_unmarshaler :: proc(ctx: yaml.Unmarshal_Context, v: any) -> yaml.Unmarshal_Error {
    switch yaml.unmarshal_ctx_node_type(ctx) {
    case .SCALAR_NODE:
        // Parse "#RRGGBB" format
        s := yaml.unmarshal_ctx_node_value(ctx)
        c := (^Color)(v.data)
        if len(s) == 7 && s[0] == '#' {
            r, r_ok := strconv.parse_int(s[1:3], 16)
            g, g_ok := strconv.parse_int(s[3:5], 16)
            b, b_ok := strconv.parse_int(s[5:7], 16)
            if r_ok && g_ok && b_ok {
                c.r = u8(r)
                c.g = u8(g)
                c.b = u8(b)
                return nil
            }
        }
        return yaml.Scalar_Conversion_Error{value = s, target_type = v.id}

    case .MAPPING_NODE:
        // Delegate {r, g, b} mapping to standard decode
        return yaml.unmarshal_ctx_decode(ctx, v)

    case .SEQUENCE_NODE, .NO_NODE:
        return nil
    }
    return nil
}

main :: proc() {
    // Set up registry
    unmarshalers: map[typeid]yaml.User_Unmarshaler
    defer delete(unmarshalers)
    yaml.set_user_unmarshalers(&unmarshalers)
    defer yaml.set_user_unmarshalers(nil)

    yaml.register_user_unmarshaler(Color, color_unmarshaler)

    Theme :: struct {
        bg: Color,
        fg: Color,
    }

    input := `
bg: "#1a2b3c"
fg:
  r: 255
  g: 255
  b: 255
`
    theme: Theme
    err := yaml.unmarshal_string(input, &theme)
    if err != nil {
        fmt.eprintfln("Error: %v", err)
        return
    }

    fmt.printfln("bg: #%2x%2x%2x", theme.bg.r, theme.bg.g, theme.bg.b)
    fmt.printfln("fg: rgb(%d, %d, %d)", theme.fg.r, theme.fg.g, theme.fg.b)
}
```

**Output:**

```
bg: #1a2b3c
fg: rgb(255, 255, 255)
```

### Sample: Duration with human-readable string parsing

```odin
import "core:fmt"
import "core:strconv"
import yaml "../.."

Duration :: struct {
    seconds: int,
}

duration_unmarshaler :: proc(ctx: yaml.Unmarshal_Context, v: any) -> yaml.Unmarshal_Error {
    if yaml.unmarshal_ctx_node_type(ctx) != .SCALAR_NODE {
        return yaml.unmarshal_ctx_decode(ctx, v)
    }

    s := yaml.unmarshal_ctx_node_value(ctx)
    d := (^Duration)(v.data)
    total := 0
    num_start := 0

    for i := 0; i < len(s); i += 1 {
        switch s[i] {
        case 'h':
            if n, ok := strconv.parse_int(s[num_start:i]); ok { total += n * 3600 }
            num_start = i + 1
        case 'm':
            if n, ok := strconv.parse_int(s[num_start:i]); ok { total += n * 60 }
            num_start = i + 1
        case 's':
            if n, ok := strconv.parse_int(s[num_start:i]); ok { total += n }
            num_start = i + 1
        }
    }

    // Plain integer → treat as seconds
    if num_start == 0 {
        if n, ok := strconv.parse_int(s); ok {
            total = n
        } else {
            return yaml.Scalar_Conversion_Error{value = s, target_type = v.id}
        }
    }

    d.seconds = total
    return nil
}

main :: proc() {
    unmarshalers: map[typeid]yaml.User_Unmarshaler
    defer delete(unmarshalers)
    yaml.set_user_unmarshalers(&unmarshalers)
    defer yaml.set_user_unmarshalers(nil)

    yaml.register_user_unmarshaler(Duration, duration_unmarshaler)

    Config :: struct {
        timeout:     Duration,
        retry_delay: Duration,
    }

    input := `
timeout: 1h30m
retry_delay: 30s
`
    cfg: Config
    yaml.unmarshal_string(input, &cfg)
    fmt.printfln("timeout:     %d seconds", cfg.timeout.seconds)
    fmt.printfln("retry_delay: %d seconds", cfg.retry_delay.seconds)
}
```

**Output:**

```
timeout:     5400 seconds
retry_delay: 30 seconds
```

### Sample: Flexible type accepting scalar, mapping, or sequence

```odin
import "core:fmt"
import "core:strconv"
import yaml "../.."

Point :: struct {
    x: int,
    y: int,
}

point_unmarshaler :: proc(ctx: yaml.Unmarshal_Context, v: any) -> yaml.Unmarshal_Error {
    switch yaml.unmarshal_ctx_node_type(ctx) {
    case .SCALAR_NODE:
        // Parse "x,y" format
        s := yaml.unmarshal_ctx_node_value(ctx)
        p := (^Point)(v.data)
        for i := 0; i < len(s); i += 1 {
            if s[i] == ',' {
                if xv, ok := strconv.parse_int(s[:i]); ok { p.x = xv }
                if yv, ok := strconv.parse_int(s[i+1:]); ok { p.y = yv }
                return nil
            }
        }
        return nil

    case .MAPPING_NODE:
        // Delegate to standard struct decoding: {x: 10, y: 20}
        return yaml.unmarshal_ctx_decode(ctx, v)

    case .SEQUENCE_NODE:
        // Positional: [10, 20]
        items := yaml.unmarshal_ctx_sequence_items(ctx)
        p := (^Point)(v.data)
        if len(items) >= 2 {
            x_node := yaml.unmarshal_ctx_get_node(ctx, items[0])
            y_node := yaml.unmarshal_ctx_get_node(ctx, items[1])
            if x_node != nil {
                yaml.unmarshal_ctx_decode_node(ctx, x_node, any{&p.x, typeid_of(int)})
            }
            if y_node != nil {
                yaml.unmarshal_ctx_decode_node(ctx, y_node, any{&p.y, typeid_of(int)})
            }
        }
        return nil

    case .NO_NODE:
        return nil
    }
    return nil
}
```

This unmarshaler allows all three YAML representations for the same `Point` type:

```yaml
# Scalar form
origin: "10,20"

# Mapping form
origin:
  x: 10
  y: 20

# Sequence form
origin: [10, 20]
```
