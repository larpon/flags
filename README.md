# flags

A V module for mapping and documenting different flag styles (as typically found in in `os.args`)
into user defined V `struct`s via compile time reflection.

The module supports several flag "styles" like:

* POSIX short style (`-v`)
* POSIX short style repeats (`-vvvvv`)
* GNU long style (`--long` / `--long=value`
* Go `flag` module style (`-flag`, `-flag-name` and GNU long)
* V style (`-v`,`-version`)

# Example

Put the following V code in a file `flags_example.v` and run it with:

```bash
v run flags_example.v -h
```

```v
import flags
import os

@[xdoc: 'My application that does X']
@[name: 'app']
@[version: '1.2.3']
struct Config {
	show_version bool   @[short: v; xdoc: 'Show version and exit']
	debug_level  int    @[long: debug; short: d; xdoc: 'Debug level']
	level        f32    @[only: l; xdoc: 'This doc text is overwritten']
	example      string
	square       bool
	show_help    bool   @[long: help; short: h]
	multi        int    @[only: m; repeats]
	wroom        []int  @[short: w]
	ignore_me    string @[ignore]
}

fn main() {
	// Map POSIX and GNU style flags found in `os.args` to fields on struct `T`
	config, no_matches := flags.to_struct[Config](os.args, skip: 1)!

	if no_matches.len > 0 {
		println('The following flags could not be mapped to any fields on the struct:')
		for index in no_matches {
			println('${index}: ${os.args[no_matches[index]]}')
		}
	}

	if config.show_help {
		// Generate and layout (a configuable) documentation for the flags
		documentation := flags.to_doc[Config](
			version: '1.0' // NOTE: this overrides the `@[version: '1.2.3']` struct attribute
			fields: {
				'level':                                    'This is a doc string of the field `level` on struct `Config`'
				'example':                                  'This is another doc string'
				'multi':                                    'This flag can be repeated'
				'-e, --extra':                              'Extra flag that does not exist on the struct, but we want documented (in same format as the others)'
				'-q, --quiet-and-quite-long-flag <string>': 'This is a flag with a long name'
				'square':                                   '.____.\n|    |\n|    |\n|____|'
			}
		)!
		println(documentation)
		exit(0)
	}

	dump(config)
}
```

# Usage

The 2 most useful functions in the module is `to_struct[T]()` and `to_doc[T]()`.

## `to_struct[T](...)`

`to_struct[T](input []string, config ParseConfig) !(T, []int)` maps flags found in `input`
to *matching* fields on `T`. The matching is determined via hints that the user can
specify with special field attributes. The matching is done in the following way:

1. Match the flag name with the field name directly (`my_field` matches e.g. `--my-field`).
  * Underscores (`_`) in long field names are converted to `-`.
  * Fields with the attribute `@[ignore]` is ignored.
  * Fields with the attribute `@[only: n]` will only match if the short flag `-n` is provided.
  * Fields with the attribute `@[long: my_name]` will match the flag `--my-name`.
2. Match a field's short identifier, if specified.
  * Short identifiers are specified using `@[short: n]`
  * To map a field *solely* to a short flag use `@[only: n]`
  * Short flags that repeats is mapped to fields via the attribute `@[repeats]`

## `to_doc[T](...)`

`pub fn to_doc[T](dc DocConfig) !string` returns an auto-generated `string` with flag
documentation. The documentation can be tweaked in several ways to suit any special
user needs via the `DocConfig` configuration struct.

# Sub commands

Due to the nature of how `to_struct[T]` works it is not suited for applications that use
sub commands at first glance.
`git` and `v` are examples of command line applications that uses sub commands
e.g.: `v help xyz`, where `help` is the sub command.

To support this "flag" style in your application and still use `to_struct[T]()` you can
simply parse out your sub command prior to mapping any flags.

Try the following example.

Put the following V code in a file `subcmd.v` and run it with:

```bash
v run subcmd.v -h && v run subcmd.v sub -h && v run subcmd.v sub --do-stuff # observe the different outputs.
```

```v
import flags
import os

struct Config {
	show_help bool @[long: help; short: h; xdoc: 'Show version and exit']
}

struct ConfigSub {
	show_help bool @[long: help; short: h; xdoc: 'Show version and exit']
	do_stuff  bool @[xdoc: 'Do stuff']
}

fn main() {
	// Handle sub command `sub` if provided
	if os.args.len >= 2 && !os.args[1].starts_with('-') {
		if os.args[1] == 'sub' {
			config_for_sub, _ := flags.to_struct[ConfigSub](os.args, skip: 2)! // NOTE the `skip: 2`
			if config_for_sub.do_stuff {
				println('Working...')
				exit(0)
			}
			if config_for_sub.show_help {
				println(flags.to_doc[ConfigSub](
					description: 'My sub command'
				)!)
				exit(0)
			}
		}
	}

	config, _ := flags.to_struct[Config](os.args, skip: 1)!

	if config.show_help {
		println(flags.to_doc[Config](
			description: 'My application'
		)!)
		exit(0)
	}
}
```
