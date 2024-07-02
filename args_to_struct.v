module args_to_struct

struct Flag {
	raw        string  @[required]
	field_name string  @[required]
	delimiter  string
	name       string
	arg        ?string
	pos        int
	repeats    int = 1
}

struct FlagContext {
	raw         string @[required] // raw arg array entry
	delimiter   string // usually `'-'`
	name        string // either struct field name or what is defined in `@[long: <name>]`
	next        string // peek at what is the next flag/arg
	short_name  string // `s` in `-s`
	struct_name string // name of the struct that is getting mapped to
	pos         int    // position in arg array
}

pub enum Style {
	short // Posix short only, allows mulitple shorts -def is `-d -e -f` and "sticky" arguments e.g.: `-ofoo` = `-o foo`
	short_long // extends `posix` style shorts with GNU style long options: `--flag` or `--name=value`
	long // GNU style long option *only*. E.g.: `--name` or `--name=value`
	// go_ // GO `flag` module style. Single flag denote `-` followed by string identifier e.g.: `-verbose`, `-name value`, `-v` or `-n value` and both long `--name value` and GNU long `--name=value`
	v // V style flags as found in flags for the `v` compiler. Single flag denote `-` followed by string identifier e.g.: `-verbose`, `-name value`, `-v`, `-n value` or `-d ident=value`
	// chaos // only fields in struct T that have a style tag, which is one or more of `at`, `short: XYZ`, `long: XYZ` or `go_: XYZ`
}

struct StructInfo {
	name   string
	fields map[string]StructField
}

struct StructField {
	name       string
	match_name string
	short_name string
	is_bool    bool
	is_array   bool
	is_ignore  bool
	has_tail   bool
	short_only bool
	can_repeat bool
	attrs      map[string]string
}

@[params]
pub struct ParseConfig {
pub:
	delimiter string = '-' // delimiter used for flags
	style     Style  = .short_long // expected flag style
	stop      ?string // single, usually '--', string that stops parsing flags/options
	skip      u16     // skip this amount in the input argument array, usually `1` for skipping executable or subcmd entry
}

pub struct FlagParser {
	config ParseConfig @[required]
	input  []string    @[required]
mut:
	si                      StructInfo
	handled_fields          []string
	handled_pos             []int
	identified_fields       map[string]Flag
	identified_multi_fields map[string][]Flag
	no_match                []int // indicies of unmatched in the `input` array
}

@[if trace_flag_parser ?]
fn trace_println(str string) {
	println(str)
}

@[if trace_flag_parser ? && debug]
fn trace_dbg_println(str string) {
	println(str)
}

fn (fp FlagParser) get_struct_info[T]() !StructInfo {
	mut struct_fields := map[string]StructField{}
	mut struct_name := ''
	$if T is $struct {
		struct_name = T.name
		trace_println('${@FN}: mapping struct "${struct_name}"...')
		// Handle positional first so they can be marked as handled
		$for field in T.fields {
			mut match_name := field.name.replace('_', '-')
			trace_println('${@FN}: field "${field.name}":')
			mut attrs := map[string]string{}
			for attr in field.attrs {
				trace_println('\tattribute: "${attr}"')
				if attr.contains(':') {
					split := attr.split(':')
					attrs[split[0].trim(' ')] = split[1].trim(' ')
				} else {
					attrs[attr.trim(' ')] = 'true'
				}
			}
			if long_alias := attrs['long'] {
				match_name = long_alias
			}
			mut is_short_only := false
			if only := attrs['only'] {
				if only.len == 0 {
					return error('attribute @[only] on ${struct_name}.${match_name} can not be empty, use @[only: x]')
				} else if only.len == 1 {
					is_short_only = true
					attrs['short'] = only
				} else if only.len > 1 {
					match_name = only
				}
			}
			mut short_name := ''
			if short_alias := attrs['short'] {
				short_name = short_alias
			}
			can_repeat := if _ := attrs['repeats'] { true } else { false }
			has_tail := if _ := attrs['tail'] { true } else { false }
			is_ignore := if _ := attrs['ignore'] { true } else { false }

			mut is_bool := false
			$if field.typ is bool {
				trace_println('\tfield "${field.name}" is a bool')
				is_bool = true
			}
			mut is_array := false
			$if field.typ is []string {
				trace_println('\tfield "${field.name}" is string array')
				is_array = true
			} $else $if field.typ is []int {
				trace_println('\tfield "${field.name}" is int array')
				is_array = true
			}
			// TODO

			struct_fields[field.name] = StructField{
				name: field.name
				match_name: match_name
				is_bool: is_bool
				is_array: is_array
				is_ignore: is_ignore
				has_tail: has_tail
				can_repeat: can_repeat
				short_only: is_short_only
				short_name: short_name
				attrs: attrs
			}
		}
	} $else {
		return error('the type `${T.name}` can not be decoded.')
	}

	return StructInfo{
		name: struct_name
		fields: struct_fields
	}
}

fn (m map[string]Flag) query_flag_with_name(name string) ?Flag {
	for _, flag in m {
		if flag.name == name {
			return flag
		}
	}
	return none
}

pub fn to_struct[T](input []string, config ParseConfig) !(T, []int) {
	mut fp := FlagParser{
		config: config
		input: input
	}
	fp.parse[T]()!
	st := fp.to_struct[T]()!
	return st, fp.no_matches()
}

pub fn (fp FlagParser) no_matches() []int {
	return fp.no_match

	// is_flag := flag.starts_with(delimiter)
	// if !is_flag {
	// 	if pos == fp.input.len - 1 {
	// 		return error('no match for the last entry `${flag}` in ${style} style parsing mode')
	// 	} else {
	// 		return error('no match for `${flag}` at index ${pos} in ${style} style parsing mode')
	// 	}
	// }
	// return error('no match for flag `${flag}` at index ${pos} in ${style} style parsing mode')
	//
	// if fp.no_match.len > 0 {
	// 	mut no_match_str := '['
	// 	for index in fp.no_match {
	// 		no_match_str += '"${fp.input[index]}", '
	// 	}
	// 	no_match_str = no_match_str.trim_right(', ') + ']'
	// 	return error('could not match ${fp.no_match}')
	// }
}

pub fn (mut fp FlagParser) parse[T]() ! {
	config := fp.config
	style := config.style
	delimiter := config.delimiter
	flags := fp.input.clone() // TODO

	if config.skip > 0 {
		for i in 0 .. int(config.skip) {
			fp.handled_pos << i // skip X entry, aka. the "exe" or "executable" - or even more if user wishes
		}
	}

	// Gather runtime information about T
	fp.si = fp.get_struct_info[T]()!
	struct_name := fp.si.name

	// Get the index of the last flag (used to find any trailing args)
	// index_of_last_flag := index_of_last(flags, delimiter) // TODO can probably be removed

	for pos, flag in flags {
		if flag == '' {
			fp.no_match << pos
			continue
		}
		mut pos_is_handled := pos in fp.handled_pos
		if !pos_is_handled {
			// Stop parsing as soon as possible if `--` or user defined is encountered
			if flag == config.stop or { '' } {
				trace_println('${@FN}: reached option stop (${config.stop}) at index ${pos}')
				break
			}
		}
		mut next := ''
		if pos + 1 < flags.len {
			next = flags[pos + 1]
		}
		for field_name, field in fp.si.fields {
			if field.is_ignore {
				trace_dbg_println('${@FN}: skipping field "${field_name}" has an @[ignore] attribute')
				continue
			}
			// Field already identified, skip
			if _ := fp.identified_fields[field_name] {
				trace_dbg_println('${@FN}: skipping field "${field_name}" already identified')
				continue
			}
			field_is_handled := field_name in fp.handled_fields
			pos_is_handled = pos in fp.handled_pos
			if field_is_handled || pos_is_handled {
				trace_dbg_println('${@FN}: skipping field "${field_name}" or position "${pos}" already handled')
				continue
			}
			mut is_flag := false // `flag` starts with `-` (default value) or user defined
			mut is_stop := false // Single `--` (default value) or user defined
			mut flag_name := ''
			flag_short_name := field.short_name
			if flag.starts_with(delimiter) {
				is_flag = true
				flag_name = flag.trim_left(delimiter)
				// Parse GNU `--name=value`
				if style in [.long, .short_long] {
					flag_name = flag_name.all_before('=')
				}
				if flag == config.stop or { '' } {
					is_flag = false
					flag_name = flag
					is_stop = true
				}
			}

			// A flag, parse it and find best matching field in struct, if any
			if is_flag {
				used_delimiter := flag.all_before(flag_name)
				is_long_delimiter := used_delimiter.count(delimiter) == 2
				is_short_delimiter := used_delimiter.count(delimiter) == 1
				is_invalid_delimiter := !is_long_delimiter && !is_short_delimiter

				trace_println('${@FN}: looking at `${used_delimiter}` ${if is_long_delimiter {
					'(long)'
				} else {
					'(short)'
				}} flag "${flag}/${flag_name}" is it matching "${field_name}${if flag_short_name != '' {
					'/' + flag_short_name
				} else {
					''
				}}"?')

				if is_invalid_delimiter {
					return error('invalid delimiter `${used_delimiter}` for flag `${flag}`')
				}
				if is_long_delimiter {
					if style == .v {
						return error('long delimiter `${used_delimiter}` encountered in flag `${flag}` in ${style} (V) style parsing mode')
					}
					if style == .short {
						return error('long delimiter `${used_delimiter}` encountered in flag `${flag}` in ${style} (POSIX) style parsing mode')
					}
					if field.short_only {
						trace_println('${@FN}: skipping long delimiter `${used_delimiter}` match for ${struct_name}.${field_name} since it has [only: ${flag_short_name}]')
					}
				}

				if is_short_delimiter {
					if style == .long {
						return error('short delimiter `${used_delimiter}` encountered in flag `${flag}` in ${style} (GNU) style parsing mode')
					}
				}

				if field.is_bool {
					if flag_name == field.match_name {
						arg := if flag.contains('=') { flag.all_after('=') } else { '' }
						if arg != '' {
							return error('flag `${flag}` can not be assigned to bool field "${field_name}"')
						}
						trace_println('${@FN}: identified a match for (bool) ${struct_name}.${field_name} = ${flag}/${flag_name}/${flag_short_name}')
						fp.identified_fields[field_name] = Flag{
							raw: flag
							field_name: field_name
							delimiter: used_delimiter
							name: flag_name
							pos: pos
						}
						fp.handled_pos << pos
						continue
					}
				}

				flag_context := FlagContext{
					raw: flag
					delimiter: used_delimiter
					name: flag_name
					next: next
					short_name: flag_short_name
					struct_name: fp.si.name
					pos: pos
				}

				if is_short_delimiter {
					if style in [.short, .short_long] {
						if fp.parse_posix_short(flag_context, field)! {
							continue
						}
					} else if style == .v {
						if fp.parse_v(flag_context, field)! {
							continue
						}
					}
				}

				if is_long_delimiter {
					// Parse GNU `--name=value`
					if style in [.long, .short_long] {
						if fp.parse_gnu_long(flag_context, field)! {
							continue
						}
					}
				}
			} else if is_stop {
				trace_println('${@FN}: option stop "${flag_name}" at index "${pos}"')
			} else {
				if field.has_tail {
					if last_handled_pos := fp.handled_pos[fp.handled_pos.len - 1] {
						trace_println('${@FN}: flag `${flag}` last_handled_pos: ${last_handled_pos} pos: ${pos}')
						if pos == last_handled_pos + 1 {
							if field.is_array {
								fp.identified_multi_fields[field_name] << Flag{
									raw: flag
									field_name: field_name
									arg: flag // .arg is used when assigning at comptime to []XYZ
									pos: pos
								}
							} else {
								fp.identified_fields[field_name] = Flag{
									raw: flag
									field_name: field_name
									arg: flag
									pos: pos
								}
							}
							fp.handled_pos << pos
							continue
						}
					}
				}
			}
		}
		if pos !in fp.handled_pos && pos !in fp.no_match {
			fp.no_match << pos
			flag_name := flag.trim_left(delimiter)
			if already_flag := fp.identified_fields.query_flag_with_name(flag_name) {
				return error('flag `${flag} ${next}` is already mapped to field `${already_flag.field_name}` via `${already_flag.delimiter}${already_flag.name} ${already_flag.arg or {
					''
				}}`')
			}
		}
	}
}

pub fn (fp FlagParser) to_struct[T]() !T {
	// Generate T result
	mut result := T{}

	$if T is $struct {
		$for field in T.fields {
			if f := fp.identified_fields[field.name] {
				$if field.typ is int {
					// trace_println('${@FN}: assigning (int) ${field.name} = ${f.arg}')
					result.$(field.name) = f.arg or { '${f.repeats}' }.int()
				} $else $if field.typ is f32 {
					result.$(field.name) = f.arg or {
						return error('failed appending ${f} to ${field.name}')
					}
						.f32()
				} $else $if field.typ is f64 {
					result.$(field.name) = f.arg or {
						return error('failed appending ${f} to ${field.name}')
					}
						.f64()
				} $else $if field.typ is bool {
					if arg := f.arg {
						return error('can not assign ${arg} to bool field ${field.name}')
					}
					result.$(field.name) = true
				} $else $if field.typ is string {
					// trace_println('${@FN}: assigning (string) ${field.name} = ${f}')
					result.$(field.name) = f.arg or {
						return error('failed appending ${f} to ${field.name}')
					}
						.str()
				} $else {
					return error('field type: ${field.typ} for ${field.name} is not supported')
				}
			}
			for f in fp.identified_multi_fields[field.name] {
				$if field.typ is []string {
					// trace_println('${@FN}: adding ${field.name} << ${f.arg}')
					result.$(field.name) << f.arg or {
						return error('failed appending ${f} to ${field.name}')
					}
						.str()
				}
			}
		}
	} $else {
		return error('the type `${T.name}` can not be decoded.')
	}

	return result
}

fn (mut fp FlagParser) parse_v(flag_context FlagContext, field StructField) !bool {
	// trace_println('${@FN} looking at context: ${flag_context}\nfield: ${field}')
	flag := flag_context.raw
	flag_name := flag_context.name
	flag_short_name := flag_context.short_name
	pos := flag_context.pos
	used_delimiter := flag_context.delimiter
	arg := flag_context.next
	struct_name := flag_context.struct_name

	field_name := field.name
	if flag_name == field.match_name || flag_name == field.short_name {
		if field.is_array {
			trace_println('${@FN}: identified a match for (V style multiple occurences) ${struct_name}.${field_name} = ${flag}/${flag_name}/${flag_short_name} arg: ${arg}')
			fp.identified_multi_fields[field_name] << Flag{
				raw: flag
				field_name: field_name
				delimiter: used_delimiter
				name: flag_name
				arg: arg
				pos: pos
			}
		} else {
			trace_println('${@FN}: identified a match for (V style) ${struct_name}.${field_name} = ${flag}/${flag_name}/${flag_short_name} arg: ${arg}')
			fp.identified_fields[field_name] = Flag{
				raw: flag
				field_name: field_name
				delimiter: used_delimiter
				name: flag_name
				arg: arg
				pos: pos
			}
		}
		fp.handled_pos << pos
		fp.handled_pos << pos + 1 // arg
		return true
	}
	return false
}

fn (mut fp FlagParser) parse_gnu_long(flag_context FlagContext, field StructField) !bool {
	flag := flag_context.raw
	flag_name := flag_context.name
	flag_short_name := flag_context.short_name
	pos := flag_context.pos
	used_delimiter := flag_context.delimiter
	// mut next := flag_context.next
	struct_name := flag_context.struct_name

	field_name := field.name
	if flag_name == field.match_name {
		if !field.is_bool && fp.config.style in [.long, .short_long] && !flag.contains('=') {
			return error('long delimiter (${field_name}) `${used_delimiter}` for flag `${flag}` in ${fp.config.style} style parsing mode, expects GNU style assignment. E.g.: --name=value')
		}

		arg := if flag.contains('=') { flag.all_after('=') } else { '' }
		if field.is_array {
			trace_println('${@FN}: identified a match for (GNU style multiple occurences) ${struct_name}.${field_name} = ${flag}/${flag_name}/${flag_short_name} arg: ${arg}')
			fp.identified_multi_fields[field_name] << Flag{
				raw: flag
				field_name: field_name
				delimiter: used_delimiter
				name: flag_name
				arg: arg
				pos: pos
			}
		} else {
			trace_println('${@FN}: identified a match for (GNU style) ${struct_name}.${field_name} = ${flag}/${flag_name}/${flag_short_name} arg: ${arg}')
			fp.identified_fields[field_name] = Flag{
				raw: flag
				field_name: field_name
				delimiter: used_delimiter
				name: flag_name
				arg: arg
				pos: pos
			}
		}
		fp.handled_pos << pos
		return true
	}
	return false
}

fn (mut fp FlagParser) parse_posix_short(flag_context FlagContext, field StructField) !bool {
	flag := flag_context.raw
	mut flag_name := flag_context.name
	flag_short_name := flag_context.short_name
	pos := flag_context.pos
	used_delimiter := flag_context.delimiter
	mut next := flag_context.next
	struct_name := flag_context.struct_name

	field_name := field.name

	first_letter := flag_name.split('')[0]
	next_first_letter := if next != '' {
		next.split('')[0]
	} else {
		''
	}
	count_of_first_letter_repeats := flag_name.count(first_letter)
	count_of_next_first_letter_repeats := next.count(next_first_letter)

	// trace_println('${@FN} looking at: ${flag_context}')
	if first_letter == flag_short_name {
		// `-vvvvv`, `-vv vvv` or `-v vvvv`
		if field.can_repeat {
			mut do_continue := false
			if count_of_first_letter_repeats == flag_name.len {
				trace_println('${@FN}: identified a match for (repeatable) ${struct_name}.${field_name} = ${flag}/${flag_name}/${flag_short_name} ')
				fp.identified_fields[field_name] = Flag{
					raw: flag
					field_name: field_name
					delimiter: used_delimiter
					name: flag_name
					pos: pos
					repeats: count_of_first_letter_repeats
				}
				fp.handled_pos << pos
				do_continue = true

				if next_first_letter == first_letter
					&& count_of_next_first_letter_repeats == next.len {
					trace_println('${@FN}: field "${field_name}" allow repeats and ${flag} ${next} repeats ${
						count_of_next_first_letter_repeats + count_of_first_letter_repeats} times (via argument)')
					fp.identified_fields[field_name] = Flag{
						raw: flag
						field_name: field_name
						delimiter: used_delimiter
						name: flag_name
						pos: pos
						repeats: count_of_next_first_letter_repeats + count_of_first_letter_repeats
					}
					fp.handled_pos << pos
					fp.handled_pos << pos + 1 // next
					do_continue = true
				} else {
					trace_println('${@FN}: field "${field_name}" allow repeats and ${flag} repeats ${count_of_first_letter_repeats} times')
				}
				if do_continue {
					return true
				}
			}
		} else if field.is_array {
			split := flag_name.trim_string_left(flag_short_name)
			mut next_is_handled := true
			if split != '' {
				next = split
				flag_name = flag_name.trim_string_right(split)
				next_is_handled = false
			}

			if next == '' {
				return error('flag "${flag}" expects an argument')
			}
			trace_println('${@FN}: identified a match for (multiple occurences) ${struct_name}.${field_name} = ${flag}/${flag_name}/${flag_short_name} arg: ${next}')

			fp.identified_multi_fields[field_name] << Flag{
				raw: flag
				field_name: field_name
				delimiter: used_delimiter
				name: flag_name
				arg: next
				pos: pos
			}
			fp.handled_pos << pos
			if next_is_handled {
				fp.handled_pos << pos + 1 // next
			}
			return true
		}
	}
	if (fp.config.style == .short || field.short_only) && first_letter == flag_short_name {
		split := flag_name.trim_string_left(flag_short_name)
		mut next_is_handled := true
		if split != '' {
			next = split
			flag_name = flag_name.trim_string_right(split)
			next_is_handled = false
		}

		if next == '' {
			return error('flag "${flag}" expects an argument')
		}
		trace_println('${@FN}: identified a match for (short only) ${struct_name}.${field_name} (${field.match_name}) = ${flag_short_name} = ${next}')

		fp.identified_fields[field_name] = Flag{
			raw: flag
			field_name: field_name
			delimiter: used_delimiter
			name: flag_name
			arg: next
			pos: pos
			repeats: count_of_first_letter_repeats
		}
		fp.handled_pos << pos
		if next_is_handled {
			fp.handled_pos << pos + 1 // next
		}
		return true
	} else if flag_name == field.match_name && !(field.short_only && flag_name == flag_short_name) {
		trace_println('${@FN}: identified a match for (repeats) ${struct_name}.${field_name} = ${flag}/${flag_name}/${flag_short_name} ')
		if next == '' {
			return error('flag "${flag}" expects an argument')
		}
		fp.identified_fields[field_name] = Flag{
			raw: flag
			field_name: field_name
			delimiter: used_delimiter
			name: flag_name
			arg: next
			pos: pos
			repeats: count_of_first_letter_repeats
		}
		fp.handled_pos << pos
		fp.handled_pos << pos + 1 // next
		return true
	}
	return false
}

/*
// is_position_validator := field.name.split('').all(it in ['0','1','2','3','4','5','6','7','8','9'])
$if field.is_enum {
				} $else $if field.typ is u8 {
					// typ.$(field.name) = res[json_name]!.u64()
				} $else $if field.typ is u16 {
					// typ.$(field.name) = res[json_name]!.u64()
				} $else $if field.typ is u32 {
					// typ.$(field.name) = res[json_name]!.u64()
				} $else $if field.typ is u64 {
					// typ.$(field.name) = res[json_name]!.u64()
				} $else $if field.typ is int {
					// typ.$(field.name) = res[json_name]!.int()
				} $else $if field.typ is i8 {
					// typ.$(field.name) = res[json_name]!.int()
				} $else $if field.typ is i16 {
					// typ.$(field.name) = res[json_name]!.int()
				} $else $if field.typ is i32 {
					// typ.$(field.name) = i32(res[field.name]!.int())
				} $else $if field.typ is i64 {
					// typ.$(field.name) = res[json_name]!.i64()
				} $else $if field.typ is ?u8 {
					// typ.$(field.name) = ?u8(res[json_name]!.i64())
				} $else $if field.typ is ?i8 {
					// typ.$(field.name) = ?i8(res[json_name]!.i64())
				} $else $if field.typ is ?u16 {
					// 		typ.$(field.name) = ?u16(res[json_name]!.i64())
				} $else $if field.typ is ?i16 {
					// 		typ.$(field.name) = ?i16(res[json_name]!.i64())
				} $else $if field.typ is ?u32 {
					// 			typ.$(field.name) = ?u32(res[json_name]!.i64())
				} $else $if field.typ is ?i32 {
					// 	typ.$(field.name) = ?i32(res[json_name]!.i64())
				} $else $if field.typ is ?u64 {
					// 				typ.$(field.name) = ?u64(res[json_name]!.i64())
				} $else $if field.typ is ?i64 {
					// 		typ.$(field.name) = ?i64(res[json_name]!.i64())
				} $else $if field.typ is ?int {
					// 				typ.$(field.name) = ?int(res[json_name]!.i64())
				} $else $if field.typ is f32 {
					// typ.$(field.name) = res[json_name]!.f32()
				} $else $if field.typ is ?f32 {
					// typ.$(field.name) = res[json_name]!.f32()
				} $else $if field.typ is f64 {
					// typ.$(field.name) = res[json_name]!.f64()
				} $else $if field.typ is ?f64 {
					// typ.$(field.name) = res[json_name]!.f64()
				} $else $if field.typ is bool {
					// typ.$(field.name) = res[json_name]!.bool()
				} $else $if field.typ is ?bool {
					// 	typ.$(field.name) = res[json_name]!.bool()
				} $else $if field.typ is string {
					// typ.$(field.name) = res[json_name]!.str()
				} $else $if field.typ is ?string {
					// 	typ.$(field.name) = res[json_name]!.str()
				}
				//$else $if field.typ is time.Time {
				// typ.$(field.name) = res[json_name]!.to_time()!
				//}
				// $else $if field.typ is ?time.Time {
				// typ.$(field.name) = res[json_name]!.to_time()!
				//}
				$else $if field.is_array {
					// typ.$(field.name) = res[field.name]!.arr()
				} $else $if field.is_struct {
				} $else $if field.is_alias {
				} $else $if field.is_map {
				} $else {
					return error('The type of `${field.name}` is unknown')
				}
*/

// TODO can probably be removed
fn index_of_last(array []string, find string) int {
	for i := array.len - 1; i >= 0; i-- {
		e := array[i]
		if e.starts_with(find) {
			return i
		}
	}
	return -1
}
