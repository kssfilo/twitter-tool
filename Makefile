.SUFFIXES:
#.SECONDARY:

NAME=twitter-tool
BINNAME=twitter
VERSION=0.1.8
DESCRIPTION=Twitter Command Line Tool.simple but flexible interface to access all REST API by short abbreviated commands then easy to re-use data by JSONPath/CSV. JPG/PNG upload support.
KEYWORDS=twitter command-line command line commandline tool cli bot JSON path jsonpath CSV client  tweet list search favorite follow unfollow media jpg png upload multi-account abbreviation
NODEVER=8
LICENSE=MIT

PKGKEYWORDS=$(shell echo $$(echo $(KEYWORDS)|perl -ape '$$_=join("\",\"",@F)'))
PARTPIPETAGS="_=" "VERSION=$(VERSION)" "NAME=$(NAME)" "BINNAME=$(BINNAME)" "DESCRIPTION=$(DESCRIPTION)" 'KEYWORDS=$(PKGKEYWORDS)' "NODEVER=$(NODEVER)" "LICENSE=$(LICENSE)" 

#=

DESTDIR=dist
COFFEES=$(wildcard *.coffee)
TARGETNAMES=$(patsubst %.coffee,%.js,$(COFFEES))  twitterapi.json
TARGETS=$(patsubst %,$(DESTDIR)/%,$(TARGETNAMES))
DOCNAMES=LICENSE README.md package.json
DOCS=$(patsubst %,$(DESTDIR)/%,$(DOCNAMES))
ALL=$(TARGETS) $(DOCS)
SDK=node_modules/.gitignore
TOOLS=node_modules/.bin
SHELL=/bin/bash
USER=
ONLINE=


#=

COMMANDS=build help pack test clean test-main

.PHONY:$(COMMANDS)

default:build

build:$(TARGETS)

docs:$(DOCS)

test:test.passed

test-main:$(TARGETS) username.txt tests/test.bats tests/large.json
	cd tests;TWITTER_USER=$$(cat ../username.txt) ./test.bats
	rm tests/test.bats

tests/large.json:
	echo -n '{"test":"' >$@
	dd if=/dev/urandom bs=1k count=1024|base64 |tr -d "\n" >>$@
	echo '"}' >>$@

pack:$(ALL) test.passed |$(DESTDIR)

clean:
	-@rm -rf $(DESTDIR) username.txt package-lock.json test.passed node_modules tests/test.bats tests/large.json params-*.json 2>&1 >/dev/null ;true

configclean:
	-@rm -rf ~/.recipe-js/$(BINNAME).json

help:
	@echo "Targets:$(COMMANDS)"

#=

tests/test.bats:test.bats
ifeq ("$(ONLINE)","")
	cat $< | $(TOOLS)/partpipe ONLINETEST >$@
else
	cat $< | $(TOOLS)/partpipe ONLINETEST@ >$@
endif
	chmod +x $@

username.txt:
ifeq ("$(USER)","")
	@echo 'set USER=<twitterusername> '
	@false
else
	echo $(USER) > $@
endif

test.passed:test-main
	touch $@

$(DESTDIR):
	mkdir -p $@

$(DESTDIR)/%:% $(TARGETS) Makefile|$(SDK) $(DESTDIR)
	cat $<|$(TOOLS)/partpipe -c $(PARTPIPETAGS)  >$@

$(DESTDIR)/%.js:%.coffee $(SDK) |$(DESTDIR)
ifndef NC
	$(TOOLS)/coffee-jshint -o node $< 
endif
	head -n1 $<|grep '^#!'|sed 's/coffee/node/'  >$@ 
	cat $<|$(TOOLS)/partpipe $(PARTPIPETAGS) |$(TOOLS)/coffee -bcs >> $@
	chmod +x $@

$(SDK):package.json
	npm install
	@touch $@

#=

APINAMES=$(shell norl api_list.csv -ape '$$_=$$F[1].replace("/","@")'|tr "\n" " ")
PARAMFILES:$(patsubst %,params,%.csv,$(APINAMES))

$(DESTDIR)/twitterapi.json:twitterapi.json
	cp $< $@

twitterapi.json:api_list.csv params.flg
	norl api_list.csv  -B 't={}' -ane 't[$$F[1]]=require(`$${process.cwd()}/params-$${$$F[1].replace(/\//g,"@")}.json`)' -JE '$$_=t' >$@

params.flg:api_list.csv
	$_ $$(norl $< -ape '$$_=`params-$${$$F[1].replace(/\//g,"@")}.json`')
	touch $@

params-%.json:params-%.csv apidesc-%.txt params-%.url params-%.method
	norl $< -B 'l=[]' -ane 't={name:$$F[0],required:$$F[1],description:$$F[2]};l.push(t)' -JE $$'$$_={method:"$(shell cat params-$*.method)",url:"$(shell cat params-$*.url)",description:"$(shell cat apidesc-$*.txt)",params:l}' > $@

params-%.csv:params-%.html
	cat $< |tr -d "\n" \
	|norl -Pe '$$_=$$_.replace(/class="(odd|even)"><td><strong>(.+?)<\/strong> \((.+?)\)<\/td><td>(.+?)<\/td>/g,"class=\"$$1\"><td>$$2</td><td>$$3</td><td>$$4</td>")' \
	|norl -e 'r=/<tr +class="(?:odd|even)"><td>([A-z_.]+?)<\/td><td>([A-z].+?)<\/td><td>(.+?)<\/td>/g; while(m=r.exec($$_)){if(!m[1].match(/[A-Z]/))$$P([m[1].replace(/<.+?>/g,""),m[2],_.unescape(m[3].replace(/<.+?>/g,"").replace(/,/g," "))].join(","))}' >$@

apidesc-%.txt:params-%.html
	cat $<|tr -d "\n"| norl  -e $$'if( m=$$_.match(/toctree">.*?<p>(.+?)<\/p>/) ){ $$P(m[1].replace("\'","\\\\\'").replace(/<\/?.+?>/g,"").replace(/\..+$$/,".")) }' >$@

params-%.html:params-%.url
	curl $(shell cat $<) > $@

params-%.url:api_list.csv
	$(TOOLS)/norl $< -ane 'm=$$F[1].replace(/\//g,"@");if(m=="$*"){$$P($$F[2]);process.exit(0)}' >$@

params-%.method:api_list.csv
	$(TOOLS)/norl $< -ane 'm=$$F[1].replace(/\//g,"@");if(m=="$*"){$$P($$F[0]);process.exit(0)}' >$@

api_list.csv:|$(SDK)
	curl 'https://developer.twitter.com/en/docs/api-reference-index' |$(TOOLS)/norl -ne 'm=$$_.match(/<a class="c22_link" href="(.+?)">(POST|GET) (.+?)<\/a>/);if(m){$$P(`$${m[2]},$${m[3]},$${m[1]}`)}' \
	|norl -pe 'if($$_.match(/deprecated/))$$_=null' \
	|norl -pe 'if($$_.match(/compliance\/firehose/))$$_=null' \
	|norl -ape 'if($$_.match(/media\/upload/))$$_=null' \
	|norl -cape '$$F[1]=$$F[1].replace(/ *\(.+?\)/,"")' \
	>$@
	echo "GET,tweets/search,https://developer.twitter.com/en/docs/tweets/search/api-reference/get-search-tweets" >>$@

