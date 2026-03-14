// Example: Query libyaml version information
package version_example

import "core:c"
import "core:fmt"
import yaml "../.."

main :: proc() {
	// Get version as a string
	version_str := yaml.get_version_string()
	fmt.printfln("libyaml version: %s", version_str)

	// Get version components
	major, minor, patch: c.int
	yaml.get_version(&major, &minor, &patch)
	fmt.printfln("major=%d, minor=%d, patch=%d", major, minor, patch)
}
