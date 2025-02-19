@test "can source (1) script in default config" {
	. ./src/turv.sh
	_turv_hook
}

@test "can source (2) script in default config" {
	source ./src/turv.sh
	_turv_hook
}

@test "can run script in default config" {
	run ./src/turv.sh
}

@test "can execute with bash" {
	bash ./src/turv.sh
}

@test "can execute with zsh" {
	zsh ./src/turv.sh
}

@test "can execute zsh plugin" {
	zsh ./turv.plugin.zsh
}

# vim: ft=bash ts=2 sts=2 sw=2 et
