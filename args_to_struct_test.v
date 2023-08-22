import args_to_struct as a2s

const (
	all_style_enums                = [a2s.Style.short, .short_long, .long, .go_flag, .chaos]
	posix_gnu_style_enums          = [a2s.Style.short, .short_long, .long]
	mixed_args                     = ['/path/to/exe', 'subcmd', '-vv', 'vvv', '-version', '--mix',
		'--mix-all=all', '-ldflags', '-m', '2', '-fgh', '["test", "test"]', '-m',
		'{map: 2, ml-q:"hello"}']

	posix_and_gnu_args             = ['-vv', 'vvv', '-mwindows', '-d', 'one', '--device=two',
		'--amount=8', '-d', 'three']

	posix_and_gnu_args_with_subcmd = ['/path/to/exe', 'subcmd', '-vv', 'vvv', '-mwindows', '-d',
		'one', '--device=two', '--amount=8', '-d', 'three']

	posix_args_error               = ['/path/to/exe', '-vv', 'vvv', '-mwindows', '-m', 'gnu']
)

struct Config {
	cmd           string   @[at: 1]
	mix           bool
	linker_option string   @[only: m]
	mix_hard      bool     @[json: muh] // Test that no other attributes get picked up
	def_test      string   @[long: test; short: t] = 'def'
	device        []string @[short: d]
	paths         []string @[tail]
	amount        int = 1
	verbosity     int      @[repeats; short: v]
	show_version  bool     @[long: version]
	no_long_beef  bool     @[only: n]
}

struct LongConfig {
	mix          bool
	mix_hard     bool
	def_test     string   @[long: test] = 'def'
	paths        []string @[tail]
	amount       int = 1
	show_version bool     @[long: version]
}

fn test_args_to_struct() {
	// Test .short_long parse style
	config1 := a2s.args_to_struct[Config](posix_and_gnu_args_with_subcmd, skip_first: true)!
	assert config1.cmd == 'subcmd'
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
	assert config3.verbosity == 5
	assert config3.amount == 8
	assert config3.def_test == 'ok'
	assert 'one' in config3.device
	assert 'two' in config3.device
	assert 'three' in config3.device
	assert 'four' in config3.device
  assert config3.device.len == 4
	assert config3.linker_option == 'windows'
}

fn test_args_to_struct_error_messages() {
	// Test error for GNU long flag in .short (Posix) mode
	if _ := a2s.args_to_struct[Config](posix_and_gnu_args_with_subcmd,
		skip_first: true
		style: .short
	)
	{
		assert false, 'args_to_struct should fail here'
	} else {
		assert err.msg() == 'long delimiter encountered in flag `--device=two` in short (POSIX) style parsing mode'
	}

  // Test double mapping of flags
	if _ := a2s.args_to_struct[Config](posix_args_error,
		skip_first: true
		ignore: a2s.Ignore(.at_attr) // ignores @[at: X]
	)
	{
		assert false, 'args_to_struct should fail here'
	} else {
		assert err.msg() == 'flag `-m` is already mapped to field `linker_option`'
	}


	for e_num in all_style_enums {
		// Test error for non-flag as first arg (usually the `/path/to/executable`) - which must be skipped with `.skip_first`
		if _ := a2s.args_to_struct[Config](posix_and_gnu_args_with_subcmd,
			style: e_num
		)
		{
			assert false, 'args_to_struct should fail here'
		} else {
			//
			match_msg := 'no match for flag `/path/to/exe` at index 0 in ${e_num} style parsing mode'
			assert err.msg() == match_msg
		}
	}

	for e_num in posix_gnu_style_enums {
		if _ := a2s.args_to_struct[Config](mixed_args, skip_first: true, style: e_num) {
			assert false, 'args_to_struct should fail here'
		} else {
			if e_num == .short {
				assert err.msg() == 'long delimiter encountered in flag `--mix` in short (POSIX) style parsing mode'
			} else if e_num == .long {
				assert err.msg() == 'short delimiter encountered in flag `-vv` in long (GNU) style parsing mode'
			} else {
				assert err.msg() == 'long delimiter for flag `--mix` in short_long style parsing mode, expects GNU style assignment. E.g.: --name=value'
			}
			assert true
		}
	}
}
