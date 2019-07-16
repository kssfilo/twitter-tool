#!/usr/bin/env bats

@test "verify account" {
@PARTPIPE@ONLINETEST
	skip
@PARTPIPE@
	test "$(echo $(../dist/cli.js a/v -J '$.following' ))" = 'false'
}

@test "media upload" {
@PARTPIPE@ONLINETEST
	skip
@PARTPIPE@
	test "$(echo $(../dist/cli.js -m ok.png -u kssfilo -p 's/up' -o 's:twitter-tool media upload test passed.' -J $.text |sed 's/:\/\/.*$//' |tr -d '"'))" = 'twitter-tool media upload test passed. https'
}

@test "st/s/3" {
	diff <(../dist/cli.js -h st/s/3) sts3.txt
}

@test "status/show/:id" {
	diff <(../dist/cli.js -h status/show/:id) sts3.txt
}

@test "single quote param" {
	test "$(../dist/cli.js -n s/t -o "q:'search',lang:'ja'" -d 2>&1|grep 'params:')" = 'params:{"q":"search","lang":"ja"}'
}

@test "Javascript Object param" {
	test "$(../dist/cli.js -n s/t -o "{ q:  'search' ,  lang: 'ja'  }" -d 2>&1|grep 'params:')" = 'params:{"q":"search","lang":"ja"}'
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

@test "default output" {
	test "$(echo $(cat test.json|../dist/cli.js -T))" = "{ statuses: [ [Object], [Object] ], search_metadata: { completed_in: 0.025, max_id: 1150399715965427700, max_id_str: '1150399715965427712', next_results: '?max_id=1150381594085081087&q=%40nodejs&count=3&include_entities=1', query: '%40nodejs', refresh_url: '?since_id=1150399715965427712&q=%40nodejs&include_entities=1', count: 3, since_id: 0, since_id_str: '0' } }"
}

