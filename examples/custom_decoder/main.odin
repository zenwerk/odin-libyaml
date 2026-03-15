// Example: Custom decoder for flexible YAML unmarshaling
//
// Demonstrates how to register custom unmarshalers to handle YAML structures
// that don't map directly to Odin structs via reflection.
//
// Use cases shown:
//   1. Color — accepts both "#RRGGBB" hex string and {r, g, b} mapping
//   2. Duration — parses human-readable strings like "30s", "5m", "2h"
//   3. Endpoint — a single-element map "host:port" → struct
package custom_decoder_example

import "core:fmt"
import "core:strconv"
import "core:strings"

import yaml "../.."

// ---------------------------------------------------------------------------
// Domain Types
// ---------------------------------------------------------------------------

Color :: struct {
	r: u8,
	g: u8,
	b: u8,
}

Duration :: struct {
	seconds: int,
}

Endpoint :: struct {
	host: string,
	port: int,
}

// Application config that uses these types
App_Config :: struct {
	name:        string,
	background:  Color,
	foreground:  Color,
	timeout:     Duration,
	retry_delay: Duration,
	servers:     []Endpoint,
}

// ---------------------------------------------------------------------------
// Custom Unmarshalers
// ---------------------------------------------------------------------------

// Color: "#RRGGBB" scalar or {r, g, b} mapping
color_unmarshaler :: proc(ctx: yaml.Unmarshal_Context, v: any) -> yaml.Unmarshal_Error {
	switch yaml.unmarshal_ctx_node_type(ctx) {
	case .SCALAR_NODE:
		s := yaml.unmarshal_ctx_node_value(ctx)
		c := (^Color)(v.data)
		// Parse "#RRGGBB"
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
		// Delegate to standard struct decoding for {r: 255, g: 128, b: 0}
		return yaml.unmarshal_ctx_decode(ctx, v)

	case .SEQUENCE_NODE, .NO_NODE:
		return nil
	}
	return nil
}

// Duration: parse "30s", "5m", "2h", "1h30m" etc.
duration_unmarshaler :: proc(ctx: yaml.Unmarshal_Context, v: any) -> yaml.Unmarshal_Error {
	if yaml.unmarshal_ctx_node_type(ctx) != .SCALAR_NODE {
		return yaml.unmarshal_ctx_decode(ctx, v)
	}

	s := yaml.unmarshal_ctx_node_value(ctx)
	d := (^Duration)(v.data)
	total := 0
	num_start := 0

	for i := 0; i < len(s); i += 1 {
		ch := s[i]
		switch ch {
		case 'h':
			if n, ok := strconv.parse_int(s[num_start:i]); ok {
				total += n * 3600
			}
			num_start = i + 1
		case 'm':
			if n, ok := strconv.parse_int(s[num_start:i]); ok {
				total += n * 60
			}
			num_start = i + 1
		case 's':
			if n, ok := strconv.parse_int(s[num_start:i]); ok {
				total += n
			}
			num_start = i + 1
		}
	}

	// Plain integer (no suffix) → treat as seconds
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

// Endpoint: parse "host:port" scalar or {host, port} mapping
endpoint_unmarshaler :: proc(ctx: yaml.Unmarshal_Context, v: any) -> yaml.Unmarshal_Error {
	switch yaml.unmarshal_ctx_node_type(ctx) {
	case .SCALAR_NODE:
		s := yaml.unmarshal_ctx_node_value(ctx)
		ep := (^Endpoint)(v.data)
		// Find last colon (for IPv6 compat)
		colon := strings.last_index_byte(s, ':')
		if colon < 0 {
			ep.host = strings.clone(s, ctx.allocator) or_return
			ep.port = 80
			return nil
		}
		ep.host = strings.clone(s[:colon], ctx.allocator) or_return
		if port, ok := strconv.parse_int(s[colon+1:]); ok {
			ep.port = port
		} else {
			ep.port = 80
		}
		return nil

	case .MAPPING_NODE:
		return yaml.unmarshal_ctx_decode(ctx, v)

	case .SEQUENCE_NODE, .NO_NODE:
		return nil
	}
	return nil
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

format_duration :: proc(d: Duration) -> string {
	s := d.seconds
	if s >= 3600 {
		h := s / 3600
		m := (s % 3600) / 60
		if m > 0 {
			return fmt.tprintf("%dh%dm", h, m)
		}
		return fmt.tprintf("%dh", h)
	}
	if s >= 60 {
		return fmt.tprintf("%dm", s / 60)
	}
	return fmt.tprintf("%ds", s)
}

// ---------------------------------------------------------------------------
// Main
// ---------------------------------------------------------------------------

main :: proc() {
	// Register custom unmarshalers
	unmarshalers: map[typeid]yaml.User_Unmarshaler
	defer delete(unmarshalers)
	yaml.set_user_unmarshalers(&unmarshalers)
	defer yaml.set_user_unmarshalers(nil)

	yaml.register_user_unmarshaler(Color, color_unmarshaler)
	yaml.register_user_unmarshaler(Duration, duration_unmarshaler)
	yaml.register_user_unmarshaler(Endpoint, endpoint_unmarshaler)

	// YAML with mixed formats for each custom type
	input := `
name: my-service
background: "#1a2b3c"
foreground:
  r: 255
  g: 255
  b: 255
timeout: 1h30m
retry_delay: 30s
servers:
  - "api.example.com:8080"
  - "db.example.com:5432"
  - host: cache.example.com
    port: 6379
`

	cfg: App_Config
	err := yaml.unmarshal_string(input, &cfg)
	if err != nil {
		fmt.eprintfln("Unmarshal error: %v", err)
		return
	}

	fmt.printfln("App: %s", cfg.name)
	fmt.printfln("")
	fmt.printfln("Background: #%2x%2x%2x", cfg.background.r, cfg.background.g, cfg.background.b)
	fmt.printfln("Foreground: rgb(%d, %d, %d)", cfg.foreground.r, cfg.foreground.g, cfg.foreground.b)
	fmt.printfln("")
	fmt.printfln("Timeout:     %s (%d seconds)", format_duration(cfg.timeout), cfg.timeout.seconds)
	fmt.printfln("Retry delay: %s (%d seconds)", format_duration(cfg.retry_delay), cfg.retry_delay.seconds)
	fmt.printfln("")
	fmt.printfln("Servers:")
	for ep, i in cfg.servers {
		fmt.printfln("  [%d] %s:%d", i, ep.host, ep.port)
	}
}
