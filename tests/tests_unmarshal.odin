package tests

import "core:fmt"
import "core:math"
import "core:testing"

import yaml ".."

// ========================================================================
// 1. Basic scalar types
// ========================================================================
@(test)
test_unmarshal_basic_scalars :: proc(t: ^testing.T) {
	Config :: struct {
		name:    string,
		age:     int,
		score:   f64,
		active:  bool,
	}

	input := `
name: Alice
age: 30
score: 95.5
active: true
`
	cfg: Config
	err := yaml.unmarshal_string(input, &cfg)
	testing.expect(t, err == nil, fmt.tprintf("unmarshal error: %v", err))
	testing.expect_value(t, cfg.name, "Alice")
	testing.expect_value(t, cfg.age, 30)
	testing.expect_value(t, cfg.score, 95.5)
	testing.expect_value(t, cfg.active, true)
}

// ========================================================================
// 2. Struct tags
// ========================================================================
@(test)
test_unmarshal_struct_tags :: proc(t: ^testing.T) {
	Tagged :: struct {
		first_name: string `yaml:"first-name"`,
		last_name:  string `yaml:"last-name"`,
		age:        int,
	}

	input := `
first-name: John
last-name: Doe
age: 42
`
	v: Tagged
	err := yaml.unmarshal_string(input, &v)
	testing.expect(t, err == nil, fmt.tprintf("unmarshal error: %v", err))
	testing.expect_value(t, v.first_name, "John")
	testing.expect_value(t, v.last_name, "Doe")
	testing.expect_value(t, v.age, 42)
}

// ========================================================================
// 3. Nested structs
// ========================================================================
@(test)
test_unmarshal_nested_struct :: proc(t: ^testing.T) {
	Address :: struct {
		city:    string,
		country: string,
	}
	Person :: struct {
		name:    string,
		address: Address,
	}

	input := `
name: Bob
address:
  city: Tokyo
  country: Japan
`
	p: Person
	err := yaml.unmarshal_string(input, &p)
	testing.expect(t, err == nil, fmt.tprintf("unmarshal error: %v", err))
	testing.expect_value(t, p.name, "Bob")
	testing.expect_value(t, p.address.city, "Tokyo")
	testing.expect_value(t, p.address.country, "Japan")
}

// ========================================================================
// 4. Sequences — slice, dynamic array, fixed array
// ========================================================================
@(test)
test_unmarshal_slice :: proc(t: ^testing.T) {
	Data :: struct {
		items: []string,
	}

	input := `
items:
  - apple
  - banana
  - cherry
`
	d: Data
	err := yaml.unmarshal_string(input, &d)
	testing.expect(t, err == nil, fmt.tprintf("unmarshal error: %v", err))
	testing.expect_value(t, len(d.items), 3)
	if len(d.items) == 3 {
		testing.expect_value(t, d.items[0], "apple")
		testing.expect_value(t, d.items[1], "banana")
		testing.expect_value(t, d.items[2], "cherry")
	}
}

@(test)
test_unmarshal_dynamic_array :: proc(t: ^testing.T) {
	Data :: struct {
		values: [dynamic]int,
	}

	input := `
values:
  - 10
  - 20
  - 30
`
	d: Data
	err := yaml.unmarshal_string(input, &d)
	testing.expect(t, err == nil, fmt.tprintf("unmarshal error: %v", err))
	testing.expect_value(t, len(d.values), 3)
	if len(d.values) == 3 {
		testing.expect_value(t, d.values[0], 10)
		testing.expect_value(t, d.values[1], 20)
		testing.expect_value(t, d.values[2], 30)
	}
}

@(test)
test_unmarshal_fixed_array :: proc(t: ^testing.T) {
	Data :: struct {
		rgb: [3]int,
	}

	input := `
rgb:
  - 255
  - 128
  - 0
`
	d: Data
	err := yaml.unmarshal_string(input, &d)
	testing.expect(t, err == nil, fmt.tprintf("unmarshal error: %v", err))
	testing.expect_value(t, d.rgb[0], 255)
	testing.expect_value(t, d.rgb[1], 128)
	testing.expect_value(t, d.rgb[2], 0)
}

// ========================================================================
// 5. map[string]T
// ========================================================================
@(test)
test_unmarshal_map :: proc(t: ^testing.T) {
	Data :: struct {
		env: map[string]string,
	}

	input := `
env:
  HOME: /home/user
  PATH: /usr/bin
  SHELL: /bin/bash
`
	d: Data
	err := yaml.unmarshal_string(input, &d)
	testing.expect(t, err == nil, fmt.tprintf("unmarshal error: %v", err))
	testing.expect_value(t, len(d.env), 3)
	testing.expect_value(t, d.env["HOME"], "/home/user")
	testing.expect_value(t, d.env["PATH"], "/usr/bin")
	testing.expect_value(t, d.env["SHELL"], "/bin/bash")
}

// ========================================================================
// 6. Pointers
// ========================================================================
@(test)
test_unmarshal_pointer :: proc(t: ^testing.T) {
	Inner :: struct {
		value: int,
	}
	Outer :: struct {
		inner: ^Inner,
	}

	input := `
inner:
  value: 99
`
	o: Outer
	err := yaml.unmarshal_string(input, &o)
	testing.expect(t, err == nil, fmt.tprintf("unmarshal error: %v", err))
	testing.expect(t, o.inner != nil, "inner should not be nil")
	if o.inner != nil {
		testing.expect_value(t, o.inner.value, 99)
	}
}

@(test)
test_unmarshal_pointer_null :: proc(t: ^testing.T) {
	Outer :: struct {
		name:  string,
		extra: ^int,
	}

	input := `
name: test
extra: null
`
	o: Outer
	err := yaml.unmarshal_string(input, &o)
	testing.expect(t, err == nil, fmt.tprintf("unmarshal error: %v", err))
	testing.expect_value(t, o.name, "test")
	testing.expect(t, o.extra == nil, "extra should be nil")
}

// ========================================================================
// 7. Maybe(T)
// ========================================================================
@(test)
test_unmarshal_maybe :: proc(t: ^testing.T) {
	Data :: struct {
		name:     string,
		nickname: Maybe(string),
	}

	input := `
name: Alice
nickname: Ali
`
	d: Data
	err := yaml.unmarshal_string(input, &d)
	testing.expect(t, err == nil, fmt.tprintf("unmarshal error: %v", err))
	testing.expect_value(t, d.name, "Alice")
	nick, has_nick := d.nickname.?
	testing.expect(t, has_nick, "nickname should have value")
	if has_nick {
		testing.expect_value(t, nick, "Ali")
	}
}

// ========================================================================
// 8. Enum
// ========================================================================
@(test)
test_unmarshal_enum :: proc(t: ^testing.T) {
	Color :: enum {
		Red,
		Green,
		Blue,
	}
	Data :: struct {
		color: Color,
	}

	input := `color: Green`
	d: Data
	err := yaml.unmarshal_string(input, &d)
	testing.expect(t, err == nil, fmt.tprintf("unmarshal error: %v", err))
	testing.expect_value(t, d.color, Color.Green)
}

// ========================================================================
// 9. Null handling
// ========================================================================
@(test)
test_unmarshal_null_values :: proc(t: ^testing.T) {
	Data :: struct {
		a: string,
		b: int,
		c: bool,
	}

	// Test "null"
	input1 := `
a: null
b: 0
c: false
`
	d1: Data
	d1.a = "should-be-cleared"
	err1 := yaml.unmarshal_string(input1, &d1)
	testing.expect(t, err1 == nil, fmt.tprintf("unmarshal error: %v", err1))
	testing.expect_value(t, d1.a, "")

	// Test "~"
	input2 := `
a: ~
b: 0
c: false
`
	d2: Data
	d2.a = "should-be-cleared"
	err2 := yaml.unmarshal_string(input2, &d2)
	testing.expect(t, err2 == nil, fmt.tprintf("unmarshal error: %v", err2))
	testing.expect_value(t, d2.a, "")
}

// ========================================================================
// 10. Error cases
// ========================================================================
@(test)
test_unmarshal_invalid_yaml :: proc(t: ^testing.T) {
	Data :: struct { name: string }

	input := `
name: [invalid
`
	d: Data
	err := yaml.unmarshal_string(input, &d)
	_, is_parse_err := err.(yaml.Yaml_Parse_Error)
	testing.expect(t, is_parse_err, fmt.tprintf("expected Yaml_Parse_Error, got %v", err))
}

@(test)
test_unmarshal_type_mismatch :: proc(t: ^testing.T) {
	Data :: struct { count: int }

	input := `count: not_a_number`
	d: Data
	err := yaml.unmarshal_string(input, &d)
	_, is_conv_err := err.(yaml.Scalar_Conversion_Error)
	testing.expect(t, is_conv_err, fmt.tprintf("expected Scalar_Conversion_Error, got %v", err))
}

// ========================================================================
// 11. YAML special values
// ========================================================================
@(test)
test_unmarshal_special_floats :: proc(t: ^testing.T) {
	Data :: struct {
		pos_inf: f64,
		neg_inf: f64,
		nan_val: f64,
	}

	input := `
pos_inf: .inf
neg_inf: -.inf
nan_val: .nan
`
	d: Data
	err := yaml.unmarshal_string(input, &d)
	testing.expect(t, err == nil, fmt.tprintf("unmarshal error: %v", err))
	testing.expect(t, math.is_inf(d.pos_inf, 1), "pos_inf should be +inf")
	testing.expect(t, math.is_inf(d.neg_inf, -1), "neg_inf should be -inf")
	testing.expect(t, math.is_nan(d.nan_val), "nan_val should be NaN")
}

@(test)
test_unmarshal_hex_octal :: proc(t: ^testing.T) {
	Data :: struct {
		hex_val: int,
		oct_val: int,
	}

	input := `
hex_val: 0xFF
oct_val: 0o77
`
	d: Data
	err := yaml.unmarshal_string(input, &d)
	testing.expect(t, err == nil, fmt.tprintf("unmarshal error: %v", err))
	testing.expect_value(t, d.hex_val, 0xFF)
	testing.expect_value(t, d.oct_val, 0o77)
}

@(test)
test_unmarshal_bool_variants :: proc(t: ^testing.T) {
	Data :: struct {
		a: bool,
		b: bool,
		c: bool,
		d: bool,
		e: bool,
		f: bool,
	}

	input := `
a: yes
b: Yes
c: on
d: no
e: No
f: off
`
	d: Data
	err := yaml.unmarshal_string(input, &d)
	testing.expect(t, err == nil, fmt.tprintf("unmarshal error: %v", err))
	testing.expect_value(t, d.a, true)
	testing.expect_value(t, d.b, true)
	testing.expect_value(t, d.c, true)
	testing.expect_value(t, d.d, false)
	testing.expect_value(t, d.e, false)
	testing.expect_value(t, d.f, false)
}

// ========================================================================
// 12. Unknown keys — should be skipped
// ========================================================================
@(test)
test_unmarshal_unknown_keys :: proc(t: ^testing.T) {
	Data :: struct {
		name: string,
	}

	input := `
name: Alice
unknown_field: some_value
another_unknown: 123
`
	d: Data
	err := yaml.unmarshal_string(input, &d)
	testing.expect(t, err == nil, fmt.tprintf("unmarshal error: %v", err))
	testing.expect_value(t, d.name, "Alice")
}

// ========================================================================
// 13. yaml:"-" — field should be ignored
// ========================================================================
@(test)
test_unmarshal_ignore_field :: proc(t: ^testing.T) {
	Data :: struct {
		name:     string,
		internal: string `yaml:"-"`,
	}

	input := `
name: Bob
internal: should_not_be_set
`
	d: Data
	err := yaml.unmarshal_string(input, &d)
	testing.expect(t, err == nil, fmt.tprintf("unmarshal error: %v", err))
	testing.expect_value(t, d.name, "Bob")
	testing.expect_value(t, d.internal, "")
}

// ========================================================================
// Empty document
// ========================================================================
@(test)
test_unmarshal_empty_document :: proc(t: ^testing.T) {
	Data :: struct {
		name: string,
	}

	d: Data
	err := yaml.unmarshal_string("", &d)
	testing.expect(t, err == nil, fmt.tprintf("unmarshal error: %v", err))
	testing.expect_value(t, d.name, "")
}

// ========================================================================
// Sequence of structs
// ========================================================================
@(test)
test_unmarshal_sequence_of_structs :: proc(t: ^testing.T) {
	Item :: struct {
		name:  string,
		value: int,
	}
	Data :: struct {
		items: []Item,
	}

	input := `
items:
  - name: foo
    value: 1
  - name: bar
    value: 2
`
	d: Data
	err := yaml.unmarshal_string(input, &d)
	testing.expect(t, err == nil, fmt.tprintf("unmarshal error: %v", err))
	testing.expect_value(t, len(d.items), 2)
	if len(d.items) == 2 {
		testing.expect_value(t, d.items[0].name, "foo")
		testing.expect_value(t, d.items[0].value, 1)
		testing.expect_value(t, d.items[1].name, "bar")
		testing.expect_value(t, d.items[1].value, 2)
	}
}
