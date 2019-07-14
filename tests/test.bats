#!/usr/bin/env bats

@test "verify account" {
	test "$(echo $(../dist/cli.js  -g account/verify_credentials -J '$.following' ))" = 'false'
}

@test "-j with 2 line 1 column" {
	test "$(echo $(cat test.json|../dist/cli.js -T -j '$.statuses[*].id_str'))" = '[ "1111111111111111111", "2222222222222222222" ]'
}

@test "-j with 1 line 1 column" {
	test "$(echo $(cat test.json|../dist/cli.js -T -j '$.statuses[0].id_str'))" = '[ "1111111111111111111" ]'
}
@test "-j with 1 line 1 column" {
	test "$(echo $(cat test.json|../dist/cli.js -T -j '$.statuses[0].id_str|$.statuses[0].user.screen_name'))" = '[ [ "1111111111111111111", "kssfilo" ] ]'
}

@test "-j with 2 line 2 column" {
	test "$(echo $(cat test.json|../dist/cli.js -T -j '$.statuses[*].id_str|$.statuses[*].user.screen_name'))" = '[ [ "1111111111111111111", "kssfilo" ], [ "2222222222222222222", "nodenode" ] ]'
}

@test "-J with 1 line 1 column" {
	test "$(echo $(cat test.json|../dist/cli.js -T -J '$.statuses[*].id_str'))" = '1111111111111111111 2222222222222222222'
}

@test "-J with 2 line 1 column" {
	test "$(echo $(cat test.json|../dist/cli.js -T -J '$.statuses[0].id_str'))" = '1111111111111111111'
}

@test "-J with 1 line 1 column" {
	test "$(echo $(cat test.json|../dist/cli.js -T -J '$.statuses[0].id_str|$.statuses[0].user.screen_name'))" = '1111111111111111111,kssfilo'
}

@test "-J with 2 line 2 column" {
	test "$(echo $(cat test.json|../dist/cli.js -T -J '$.statuses[*].id_str|$.statuses[*].user.screen_name'))" = '1111111111111111111,kssfilo 2222222222222222222,nodenode'
}
