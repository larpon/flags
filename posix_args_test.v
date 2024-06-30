// Test different .short (POSIX) parse style
import args_to_struct as a2s

const exe_and_posix_args = ['/path/to/exe', '-vv', 'vvv', '-mwindows', '-t', 'abc', '-done', '-d',
	'two', '-dthree']

const exe_and_posix_args_with_tail = ['/path/to/exe', '-vvv', 'vvv', '-t', 'abc', '-done', '-d',
	'two', '-dthree', '/path/to/x', '/path/to/y', '/path/to/z']

struct Config {
	linker_option string   @[short: m]
	test          string = 'def'   @[short: t]
	device        []string @[short: d]
	paths         []string @[tail]
	verbosity     int      @[repeats; short: v]
	not_mapped    string = 'not changed'
}

fn test_pure_posix_short() {
	config := a2s.args_to_struct[Config](exe_and_posix_args, skip: 1, style: .short)!
	assert config.verbosity == 5
	assert config.test == 'abc'
	assert 'one' in config.device
	assert 'two' in config.device
	assert 'three' in config.device
	assert config.linker_option == 'windows'
	assert config.not_mapped == 'not changed'
	assert config.paths.len == 0
}

fn test_pure_posix_short_no_exe() {
	config := a2s.args_to_struct[Config](exe_and_posix_args[1..], style: .short)!
	assert config.verbosity == 5
	assert config.test == 'abc'
	assert 'one' in config.device
	assert 'two' in config.device
	assert 'three' in config.device
	assert config.linker_option == 'windows'
	assert config.not_mapped == 'not changed'
	assert config.paths.len == 0
}

fn test_pure_posix_short_with_tail() {
	config := a2s.args_to_struct[Config](exe_and_posix_args_with_tail, skip: 1, style: .short)!
	assert config.verbosity == 6
	assert config.test == 'abc'
	assert 'one' in config.device
	assert 'two' in config.device
	assert 'three' in config.device
	assert config.linker_option == ''
	assert config.not_mapped == 'not changed'
	assert config.paths.len == 3
	assert config.paths[0] == '/path/to/x'
	assert config.paths[1] == '/path/to/y'
	assert config.paths[2] == '/path/to/z'
}

fn test_pure_posix_short_with_tail_no_exe() {
	config := a2s.args_to_struct[Config](exe_and_posix_args_with_tail[1..], style: .short)!
	assert config.verbosity == 6
	assert config.test == 'abc'
	assert 'one' in config.device
	assert 'two' in config.device
	assert 'three' in config.device
	assert config.linker_option == ''
	assert config.not_mapped == 'not changed'
	assert config.paths.len == 3
	assert config.paths[0] == '/path/to/x'
	assert config.paths[1] == '/path/to/y'
	assert config.paths[2] == '/path/to/z'
}
