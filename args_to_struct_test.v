import args_to_struct as a2s

const all_style_enums = [a2s.Style.short, .short_long, .long, .v]
const posix_gnu_style_enums = [a2s.Style.short, .short_long, .long]
const mixed_args = ['/path/to/exe', 'subcmd', '-vv', 'vvv', '-version', '--mix', '--mix-all=all',
	'-ldflags', '-m', '2', '-fgh', '["test", "test"]', '-m', '{map: 2, ml-q:"hello"}']

const posix_and_gnu_args = ['-vv', 'vvv', '-mwindows', '-d', 'one', '--device=two', '--amount=8',
	'-d', 'three']

const posix_and_gnu_args_with_subcmd = ['/path/to/exe', 'subcmd', '-vv', 'vvv', '-mwindows', '-d',
	'one', '--device=two', '--amount=8', '-d', 'three']

const posix_and_gnu_args_with_subcmd_and_paths = ['/path/to/exe', 'subcmd', '-vv', 'vvv', '-mwindows',
	'-d', 'one', '--device=two', '--amount=8', '-d', 'three', '/path/to/a', '/path/to/b']

const posix_args_error = ['/path/to/exe', '-vv', 'vvv', '-mwindows', '-m', 'gnu']
const gnu_args = ['--f=10.2', '--mix', '--test=test', '--amount=5', '--version=1.2.3', 'other']
const gnu_args_error = ['--f=10.2', '--mix', '--test=test', '--amount=5', '--version=1.2.3', 'other',
	'oo']
const ignore_args_error = ['--show-version', '--some-test=ouch', '--amount=5', 'end']

struct Config {
	cmd           string   @[at: 1]
	mix           bool
	linker_option string   @[only: m]
	mix_hard      bool     @[json: muh] // Test that no other attributes get picked up
	def_test      string = 'def'   @[long: test; short: t]
	device        []string @[short: d]
	paths         []string @[tail]
	amount        int = 1
	verbosity     int      @[repeats; short: v]
	show_version  bool     @[long: version]
	no_long_beef  bool     @[only: n]
}

struct LongConfig {
	f            f32
	mix          bool
	some_test    string = 'abc' @[long: test]
	path         string @[tail]
	amount       int = 1
	show_version bool   @[long: version]
}

struct IgnoreConfig {
	some_test    string = 'abc' @[ignore]
	path         string @[tail]
	amount       int = 1
	show_version bool
}

fn test_args_to_struct() {
	// Test .short_long parse style
	config1 := a2s.args_to_struct[Config](posix_and_gnu_args_with_subcmd, skip: 1)!
	assert config1.cmd == 'subcmd'
	assert config1.mix == false
	assert config1.verbosity == 5
	assert config1.amount == 8
	assert config1.def_test == 'def'
	assert 'one' in config1.device
	assert 'two' in config1.device
	assert 'three' in config1.device
	assert config1.linker_option == 'windows'

	config2 := a2s.args_to_struct[Config](posix_and_gnu_args,
		ignore: a2s.Ignore(.at_attr) // ignores @[at: X]
	)!
	assert config2.cmd == ''
	assert config2.mix == false
	assert config2.verbosity == 5
	assert config2.amount == 8
	assert config2.def_test == 'def'
	assert 'one' in config2.device
	assert 'two' in config2.device
	assert 'three' in config2.device
	assert config2.device.len == 3
	assert config2.linker_option == 'windows'

	mut posix_and_gnu_args_plus_test := posix_and_gnu_args.clone()
	posix_and_gnu_args_plus_test << ['--test=ok', '-d', 'four']
	config3 := a2s.args_to_struct[Config](posix_and_gnu_args_plus_test,
		ignore: a2s.Ignore(.at_attr) // ignores @[at: X]
	)!
	assert config3.cmd == ''
	assert config3.mix == false
	assert config3.verbosity == 5
	assert config3.amount == 8
	assert config3.def_test == 'ok'
	assert config3.device.len == 4
	assert 'one' == config3.device[0]
	assert 'two' == config3.device[1]
	assert 'three' == config3.device[2]
	assert 'four' == config3.device[3]
	assert config3.linker_option == 'windows'

	config4 := a2s.args_to_struct[Config](posix_and_gnu_args_with_subcmd_and_paths, skip: 1)!
	assert config4.cmd == 'subcmd'
	assert config4.verbosity == 5
	assert config4.amount == 8
	assert config4.def_test == 'def'
	assert config4.device.len == 3
	assert 'one' == config4.device[0]
	assert 'two' == config4.device[1]
	assert 'three' == config4.device[2]
	assert config4.linker_option == 'windows'
	assert config4.paths.len == 2
	assert config4.paths[0] == '/path/to/a'
	assert config4.paths[1] == '/path/to/b'
}

fn test_long_args_to_struct() {
	// Test .long parse style
	lc1 := a2s.args_to_struct[LongConfig](gnu_args, style: .long)!
	assert lc1.f == 10.2
	assert lc1.mix == true
	assert lc1.some_test == 'test'
	assert lc1.path == 'other'
	assert lc1.amount == 5
	assert lc1.show_version == true
}

fn test_args_to_struct_error_messages() {
	// Test error for GNU long flag in .short (Posix) mode
	if _ := a2s.args_to_struct[Config](posix_and_gnu_args_with_subcmd,
		skip: 1
		style: .short
	)
	{
		assert false, 'args_to_struct should not have reached this assert'
	} else {
		assert err.msg() == 'long delimiter `--` encountered in flag `--device=two` in short (POSIX) style parsing mode'
	}

	// Test double mapping of flags
	if _ := a2s.args_to_struct[Config](posix_args_error,
		skip: 1
		ignore: a2s.Ignore(.at_attr) // ignores @[at: X]
	)
	{
		assert false, 'args_to_struct should not have reached this assert'
	} else {
		assert err.msg() == 'flag `-m` is already mapped to field `linker_option` via `-m windows`'
	}

	for e_num in all_style_enums {
		// Test error for non-flag as first arg (usually the `/path/to/executable`) - which must be skipped with `.skip`
		if _ := a2s.args_to_struct[Config](posix_and_gnu_args_with_subcmd,
			style: e_num
		)
		{
			assert false, 'args_to_struct should not have reached this assert'
		} else {
			//
			match_msg := 'no match for `/path/to/exe` at index 0 in ${e_num} style parsing mode'
			assert err.msg() == match_msg
		}
	}

	for e_num in posix_gnu_style_enums {
		if _ := a2s.args_to_struct[Config](mixed_args, skip: 1, style: e_num) {
			assert false, 'args_to_struct should not have reached this assert'
		} else {
			if e_num == .short {
				assert err.msg() == 'long delimiter `--` encountered in flag `--mix` in short (POSIX) style parsing mode'
			} else if e_num == .long {
				assert err.msg() == 'short delimiter `-` encountered in flag `-vv` in long (GNU) style parsing mode'
			} else {
				assert err.msg() == 'no match for flag `--mix-all=all` at index 6 in short_long style parsing mode'
				// TODO catch this: assert err.msg() == 'long delimiter `--` for flag `--mix` in short_long style parsing mode, expects GNU style assignment. E.g.: --name=value'
			}
			assert true
		}
	}
	if _ := a2s.args_to_struct[LongConfig](gnu_args_error, style: .long) {
		assert false, 'args_to_struct should not have reached this assert'
	} else {
		assert err.msg() == 'no match for the last entry `oo` in long style parsing mode'
	}

	if _ := a2s.args_to_struct[IgnoreConfig](ignore_args_error, style: .long) {
		assert false, 'args_to_struct should not have reached this assert'
	} else {
		assert err.msg() == '??'
	}
}
