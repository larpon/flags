import args_to_struct as a2s

const mixed_args = ['/path/to/exe','subcmd','-vv','vvv','-version','--mix','--mix-all=all','-ldflags','-m','2','-fgh','["test", "test"]','-m','{map: 2, ml-q:"hello"}']
const posix_args_with_subcmd = ['/path/to/exe','subcmd','-vv','vvv','-mwindows']
const posix_args_error = ['/path/to/exe','-vv','vvv','-mwindows','-m','gnu']

struct Config {
	cmd           string   @[at: 1]
	mix           bool
	linker_option string   @[only: m]
	mix_hard      bool     @[json: muh]
	def_test      string   @[long: test; short: t] = 'def'
	device        []string
	paths         []string @[tail]
	amount        int = 1
	verbosity     int      @[repeats; short: v]
	show_version  bool     @[long: version]
	no_long_beef  bool     @[only: n]
}

fn test_args_to_struct() {
	config := a2s.args_to_struct[Config](posix_args_with_subcmd)!
  assert config.cmd == 'subcmd'
  assert config.verbosity == 5
}


