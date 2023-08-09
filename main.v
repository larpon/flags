module main

import os

fn main() {
	dump(args_to_struct[Config](os.args,
		validate: {
			'cmd': fn (name string, arg ?string, pos int) bool {
				return pos == 1 && name in ['foo', 'bar']
			}
		}
	)!)
}

[params]
struct ArgsToStructConfig {
	validate map[string]fn (string, ?string, int) bool
}

struct Config {
	cmd      string [required]
	mix      bool = true
	mix_hard bool   [json: muh]
	def_test string
}

fn args_to_struct[T](input []string, config ArgsToStructConfig) !T {
	dump(input)
	mut result := T{}
	$if T is $struct {
		$for field in T.fields {
			mut field_name := field.name
			println('${field_name}:')
			for attr in field.attrs {
				println('\t${attr}')
				if attr.contains('pos:') {
					// field_value = attr.replace('pos:', '').trim(' ')
					// break
				}
			}

			// println(field_name)
      
      
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
		}
	} $else {
		return error("The type `${T.name}` can't be decoded.")
	}

	return result
}
