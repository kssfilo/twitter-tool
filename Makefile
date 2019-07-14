.SUFFIXES:

NAME=cli-twitter
BINNAME=twitter
VERSION=0.0.1
DESCRIPTION=Command Line Twitter Client. simple but flexible interface to Twitter REST API powered by twitter.js/jsonpath-plus. (multi-account/tweet/search/favorite/follow/unfollow/media upload)
KEYWORDS=twitter command-line command line commandline client REST API tweet search favorite follow unfollow media upload jsonpath json path multi-account
NODEVER=8
LICENSE=MIT

PKGKEYWORDS=$(shell echo $$(echo $(KEYWORDS)|perl -ape '$$_=join("\",\"",@F)'))
PARTPIPETAGS="_@" "VERSION@$(VERSION)" "NAME@$(NAME)" "BINNAME@$(BINNAME)" "DESCRIPTION@$(DESCRIPTION)" 'KEYWORDS@$(PKGKEYWORDS)' "NODEVER@$(NODEVER)" "LICENSE@$(LICENSE)" 

#=

DESTDIR=dist
COFFEES=$(wildcard *.coffee)
TARGETNAMES=$(patsubst %.coffee,%.js,$(COFFEES)) 
TARGETS=$(patsubst %,$(DESTDIR)/%,$(TARGETNAMES))
DOCNAMES=LICENSE README.md package.json
DOCS=$(patsubst %,$(DESTDIR)/%,$(DOCNAMES))
ALL=$(TARGETS) $(DOCS)
SDK=node_modules/.gitignore
TOOLS=node_modules/.bin
USER=


#=

COMMANDS=build help pack test clean test-main

.PHONY:$(COMMANDS)

default:build

build:$(TARGETS)

docs:$(DOCS)

test:test.passed

test-main:$(TARGETS) username.txt tests/test.bats
	TWITTER_USER=$$(cat username.txt) dist/cli.js  -g account/verify_credentials -J '$.following' -d
	cd tests;TWITTER_USER=$$(cat ../username.txt) ./test.bats

pack:$(ALL) test.passed |$(DESTDIR)

clean:
	-@rm -rf $(DESTDIR) username.txt package-lock.json test.passed node_modules 2>&1 >/dev/null ;true

configclean:
	-@rm -rf ~/.recipe-js/$(BINNAME).json

help:
	@echo "Targets:$(COMMANDS)"

#=

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

