module main

import os

fn main() {
	dump(args_to_struct[Config](os.args,
		validate: {
			'cmd':    fn (flag Flag) ! {
				if flag.name !in ['foo', 'bar', 'lol'] {
					return error('${flag.name} can only be one of foo, bar or lol')
				}
				if flag.pos != 1 {
					return error('${flag.name} is expected to be at position 1, not ${flag.pos}')
				}
			}
			'amount': fn (flag Flag) ! {
				if arg := flag.arg {
					if !(arg.int() >= 1 && arg.int() <= 3) {
						return error('${flag.name} has to be between 1 and 3')
					}
				}
			}
		}
	)!)
}

struct Flag {
	raw       string  [required]
	delimiter string
	name      string
	arg       ?string
	pos       int
	repeats   int = 1
}

[params]
struct ArgsToStructConfig {
	validate        map[string]fn (Flag) !
	delimiter       string = '-'
	style           Style  = .short_long
	option_stop     string = '--'
	error_reporting ErrorReporting = .relaxed
}

enum ErrorReporting {
	strict
	relaxed
}

enum Style {
	short // Posix short only, allows mulitple shorts -def is `-d -e -f` and "sticky" arguments e.g.: `-ofoo` = `-o foo`
	short_long // extends `posix` style shorts with GNU style long options: `--flag` or `--name=value`
	long // GNU style long option *only*. E.g.: `--name` or `--name=value`
	go_flag // GO `flag` module style. Single flag denote `-` followed by string identifier e.g.: `-verbose` or `-v` and both long `--name value` and GNU long `--name=value`
	chaos // only fields in struct T that have a style tag, which is one or more of `at`, `short: XYZ`, `long: XYZ` or `go_flag: XYZ`
}

struct StructField {
	name       string
	is_bool    bool
	is_multi   bool
	short_only bool
	can_repeat bool
	attrs      map[string]string
}

struct Config {
	cmd           string   @[at: 1]
	mix           bool
	linker_option string   @[short_only: m]
	mix_hard      bool     @[json: muh]
	def_test      string   @[long: test; short: t] = 'def'
	device        []string
	paths         []string @[tail]
	amount        int = 1
	verbosity     int      @[repeats; short: v]
	show_version  bool     @[long: version]
	no_long_beef  bool     @[short_only: n]
}

fn args_to_struct[T](input []string, config ArgsToStructConfig) !T {
	dump(input)
	mut style := config.style
	mut result := T{}
	mut ignored := []string{}
	mut left := input.clone()
	mut flags := input.clone()

	mut struct_fields := map[string]StructField{}

	mut handled_fields := []string{}
	mut identified_fields := map[string]Flag{}
	mut identified_multi_fields := map[string][]Flag{}
	mut handled_pos := []int{}
	handled_pos << 0 // skip exe entry

	mut struct_name := ''
	// First pass gathers information and sets positional `at: X` fields
	$if T is $struct {
		struct_name = T.name
		$for attr in T.attributes {
			println('${T.name} attribute ${attr}')
		}
		// Handle positional first so they can be marked as handled
		$for field in T.fields {
			mut field_name := field.name.replace('_', '-')
			println('looking at "${field.name}":')
			mut attrs := map[string]string{}
			for attr in field.attrs {
				println('\tattribute: "${attr}"')
				if attr.contains(':') {
					split := attr.split(':')
					attrs[split[0].trim(' ')] = split[1].trim(' ')
				} else {
					attrs[attr.trim(' ')] = 'true'
				}
			}
			if at_pos := attrs['at'] {
				attr_value := at_pos.int()
				if entry := input[attr_value] {
					index := input.index(entry)
					/*
					if validator := config.validate[field.name] {
							validator(Flag{
								name: entry
								pos: index
							})!
						}*/
					$if field.typ is string {
						result.$(field.name) = entry
					}
					println('Identified a match (at: ${attr_value}) for ${struct_name}.${field_name} = ${entry}')
					handled_fields << field.name
					handled_pos << index
				}
			}
			if long_alias := attrs['long'] {
				field_name = long_alias
			}
			mut is_short_only := false
			mut short_name := ''
			if short_only := attrs['short_only'] {
				is_short_only = true
				if short_only == '' {
					return error('attribute @[short_only] on ${struct_name}.${field_name} can not be empty, use @[short_only: x]')
				}
				attrs['short'] = short_only
			}
			can_repeat := if _ := attrs['repeats'] { true } else { false }

			mut is_bool := false
			$if field.typ is bool {
				is_bool = true
			}
			mut is_multi := false
			$if field.typ is []string {
				is_multi = true
			} $else $if field.typ is []int {
				is_multi = true
			}
			// TODO

			struct_fields[field.name] = StructField{
				name: field_name
				is_bool: is_bool
				is_multi: is_multi
				can_repeat: can_repeat
				short_only: is_short_only
				attrs: attrs
			}
		}
	} $else {
		return error('The type `${T.name}` can not be decoded.')
	}

	println('second pass ${struct_name}')
	dump(flags)
	//  mut skip_pos
	delimiter := config.delimiter
	for pos, flag in flags {
		mut next := ''
		if n := flags[pos + 1] {
			next = n
		}
		for field_real_name, field in struct_fields {
			if _ := identified_fields[field.name] {
				// println(id_flag)
				continue
			}
			if field_real_name !in handled_fields && pos !in handled_pos {
				/*
				for attr, val in field.attrs {
					println('\tattribute: "${attr}:${val}"')
					// if attr := field.s''.contains('short:') {
					//	attr_value := attr.replace('short:', '').trim(' ')
					//}
				}
				*/

				mut is_flag := false
				mut is_option_stop := false // Single `--`
				mut flag_name := ''
				if flag.starts_with(delimiter) {
					is_flag = true
					flag_name = flag.trim_left(delimiter)
					if flag == config.option_stop {
						is_flag = false
						flag_name = flag
						is_option_stop = true
					}
				}

				// A flag, parse it and find best matching field in struct
				if is_flag {
					used_delimiter := flag.trim_string_right(flag_name)
					is_long_delimiter := used_delimiter.count(delimiter) == 2
					is_short_delimiter := used_delimiter.count(delimiter) == 1
					is_invalid_delimiter := !is_long_delimiter && !is_short_delimiter

					mut flag_short_name := ''
					if short_attr := field.attrs['short'] {
						flag_short_name = short_attr
					}
					println('looking at ${used_delimiter} ${if is_long_delimiter {
						'long'
					} else {
						'short'
					}} flag "${flag}/${flag_name}" is it matching "${field_real_name}/${flag_short_name}"?')

					if is_invalid_delimiter {
						return error('invalid delimiter "${used_delimiter}" for flag "${flag}"')
					}
					if is_long_delimiter {
						if style == .short {
							return error('long delimiter encountered in flag ${flag} in ${style} (POSIX) style parsing mode')
						}
						if !field.is_bool && style in [.long, .short_long] && !flag.contains('=') {
							return error('long delimiter for flag ${flag} in ${style} style parsing mode, expects GNU style assignment. E.g.: --name=value')
						}
						if field.short_only {
							println('Skipping long delimiter match for ${struct_name}.${field_real_name} since it has [short_only: ${flag_short_name}]')
						}
					}

					if is_short_delimiter {
						if style == .long {
							return error('short delimiter encountered in flag ${flag} in ${style} (GNU) style parsing mode')
						}
					}

					if field.is_bool {
						if flag_name == field.name {
							println('Identified a match for (bool) ${struct_name}.${field_real_name} = ${flag}/${flag_name}/${flag_short_name}')
							identified_fields[field_real_name] = Flag{
								raw: flag
								delimiter: used_delimiter
								name: flag_name
								pos: pos
							}
							handled_pos << pos
							continue
						}
					}

					first_letter := flag_name.split('')[0]
					next_first_letter := next.split('')[0]
					count_of_first_letter_repeats := flag_name.count(first_letter)
					count_of_next_first_letter_repeats := next.count(next_first_letter)
					if is_short_delimiter {
						if first_letter == flag_short_name {
							// `-vvvvv`, `-vv vvv` or `-v vvvv`
							if field.can_repeat {
								mut do_continue := false
								if count_of_first_letter_repeats == flag_name.len {
									print('Identified a match for (repeatable) ${struct_name}.${field_real_name} = ${flag}/${flag_name}/${flag_short_name} ')
									identified_fields[field_real_name] = Flag{
										raw: flag
										delimiter: used_delimiter
										name: flag_name
										pos: pos
										repeats: count_of_first_letter_repeats
									}
									handled_pos << pos
									do_continue = true

									if next_first_letter == first_letter
										&& count_of_next_first_letter_repeats == next.len {
										println('field "${field_real_name}" allow repeats and ${flag} ${next} repeats ${
											count_of_next_first_letter_repeats +
											count_of_first_letter_repeats} times (via argument)')
										identified_fields[field_real_name] = Flag{
											raw: flag
											delimiter: used_delimiter
											name: flag_name
											pos: pos
											repeats: count_of_next_first_letter_repeats +
												count_of_first_letter_repeats
										}
										handled_pos << pos
										handled_pos << pos + 1 // next
										do_continue = true
									} else {
										println('field "${field_real_name}" allow repeats and ${flag} repeats ${count_of_first_letter_repeats} times')
									}
									if do_continue {
										continue
									}
								}
							}
						}
					}

					if is_short_delimiter && field.short_only && first_letter == flag_short_name {
						split := flag_name.trim_string_left(flag_short_name)
						mut next_is_handled := true
						if split != '' {
							next = split
							next_is_handled = false
						}

						if next == '' {
							return error('flag "${flag}" expects an argument')
						}
						println('Identified a match for (short only) ${struct_name}.${field_real_name} (${field.name}) = ${flag_short_name} = ${next}')
						identified_fields[field_real_name] = Flag{
							raw: flag
							delimiter: used_delimiter
							name: flag_name
							arg: next
							pos: pos
							repeats: count_of_first_letter_repeats
						}
						handled_pos << pos
						if next_is_handled {
							handled_pos << pos + 1 // next
						}
						continue
					} else if flag_name == field.name && !(field.short_only
						&& flag_name == flag_short_name) {
						println('Identified a match for ${struct_name}.${field_real_name} = ${flag}/${flag_name}/${flag_short_name} ')
						if next == '' {
							return error('flag "${flag}" expects an argument')
						}
						identified_fields[field_real_name] = Flag{
							raw: flag
							delimiter: used_delimiter
							name: flag_name
							arg: next
							pos: pos
							repeats: count_of_first_letter_repeats
						}
						handled_pos << pos
						handled_pos << pos + 1 // next
						continue
					}

					// handled_pos << pos
				} else if is_option_stop {
					println('option stop "${flag_name}" at index "${pos}"')
				} else {
					// if flag !in ignored {
					//	ignored << flag
					//}
					//
					// return error('invalid flag "${flag}"')
					// println('looking at non-flag "${flag}" "${field.name}":')
				}

				/*
				if validator := config.validate[field.name] {
						validator(Flag{
							name: field.name
							pos: pos
						})!
					}*/
			}
		}
		if pos !in handled_pos && flag !in ignored {
			println('No match for ${flag} at index ${pos}')
			if config.error_reporting == .strict {
				return error('No match for ${flag} at index ${pos}')
			}
			ignored << flag
		}
		// flags.delete(pos)
	}

	println('Could not parse ${ignored}')

	return result
}

fn value[T]() !T {}

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
