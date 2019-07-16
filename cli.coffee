#!/usr/bin/env coffee
GetOpt=require '@kssfilo/getopt'
Fs=require 'fs'
Path=require 'path'
Util=require 'util'
{RecipeNodeJs}=require 'recipe-js'
_=require 'lodash'

TwitterDoc=require './twitterapi.json'

AppName="@PARTPIPE@BINNAME@PARTPIPE@"
PackageName="@PARTPIPE@NAME@PARTPIPE@"
JSONPathUrl="https://goessner.net/articles/JsonPath/"

P=console.log
E=(e)=>
	switch
		when typeof(e) in ['string','value']
			console.error e
		when ctx.isDebugMode
			console.error e
		else
			if e[0]?.message
				console.error e[0].message
			else
				console.error.toString()

D=(str)=>
	E "#{AppName}:"+str if ctx.isDebugMode


findShortestAbbreviation=(k,candiates,sep)=>
	s=k.split sep
	ds=for a,i in s
		if sep is '/' and a is ':id'
			[a]
		else
			a.substr(0,j) for j in [1..a.length]

	f=(c,rst,sep,resultArray)=>
		if rst.length == 0
			resultArray.push c
			return c
		myRst=[].concat rst
		d=myRst.shift()
		r=for i in d
			b=_.concat c,i
			f b,myRst,sep,resultArray
		r
			
	ra=[]
	f [],ds,sep,ra
	ra=(i.join(sep) for i in ra)
	ra.sort (a,b)=>if a.length > b.length then 1 else -1

	wasDebugMode=ctx.isDebugMode
	ctx.isDebugMode=false   #turn off debug mode tempolary
	shortest=k
	for i in ra
		try
			resolveAbbreviation i,sep,candiates,false
			shortest=i
			break
		catch e
			true
	ctx.isDebugMode=wasDebugMode

	shortest
	

resolveAbbreviation=(abr,sep,cand,keepId=true)=>
	D "checking abbreviations for #{if sep is '/' then 'restCommand' else 'param'} "

	a=abr
	if sep is '/'
		id=a.match(/\/(\d+)$/)?[1]
		a=a.replace /\/\d+$/,"/:id"

	if abr in cand
		D "#{a} is found in command/param list."
		return abr

	s=a.split sep

	s2=((if i isnt ':id' then i+"[^#{sep}]*?" else i) for i in s).join(sep)
	s2="^#{s2}$"
	D "trying to search by #{s2}"
	f=cand.filter (i)=>i.match(new RegExp(s2))

	if f.length == 0
		if ctx.isForceExecute
			return abr

		if sep is '/'
			throw "there are no such command '#{a}'. see -h"
		if sep is '_'
			throw "there are no such param '#{a}'. see -h <command>"
	else if f.length >= 2
		throw "ambiguous command/param '#{a}'. candiates are #{JSON.stringify f}"
	else
		abr=f[0]
		if sep is '/' and keepId
			abr=abr.replace /:id/,id if id?
		D "matched:#{abr}"
		return abr

getCommandList=(doc,width=null)=>
	r=[]
	for k in Object.keys(doc)
		r.push "#{k} (#{findShortestAbbreviation k,Object.keys(doc),'/'})"
	
	r.sort()

	if !width?
		r.join(" | ")
	else
		maxlen=_.max(i.length for i in r)
		D maxlen
		for v,i in r
			r[i]=_.padEnd(v,maxlen)
		
		num=width//maxlen
		D num
		sr=''
		i=0
		while(s=r.shift())
			sr+=r.shift()
			i++
			sr+="\n" if i%num is 0
		sr

getParamsList=(command,doc)=>
	r=[]
	d=doc[command].params
	pns=(i.name for i in  d)

	for k in pns
		r.push "#{k}(#{findShortestAbbreviation k,pns,'_'})"

	maxlen=_.max (i.length for i in r)
	for v,i in r
		r[i]=_.padEnd v,maxlen

	for v,i in d
		r[i]+=" : #{v.required} : #{v.description}"
		
	r.join("\n")

ctx={
	isDebugMode:false
	isRecipeJsDebugMode:false
	userName:process?.env['TWITTER_USER'] ? null
	command:'auto'
	restParam:null
	outputJsonSeparator:"\t"
	jsonPath:null
	outputCsv:false
	outputFileName:null
	uploadFiles:[]
	isCheckCommand:false
	isRemoveReturnCode:false
	isForceExecute:false
	inspectDepth:0
	inspectAdjustCount:5
}

optUsages=
	h:["command","show help and command list.if you specify command name, you can see details."]
	"?":["command",""]
	d:"debug mode"
	D:"debug mode (+ recipe-js debug messages)"
	u:["username","specify your user name like @username or username. you can set default by TWITTER_USER environment variable "]
	g:["command","force GET request.command is Twitter REST Api command. e.g. 'search/tweets'. see $ #{AppName} -h"]
	p:["command","force POST request. normally,you don't need to specify -g or -p . #{PackageName} guesses method by command"]
	o:["jsonstring","parameters for GET/POST request. JSON format like '{\"q\":\"#nodejs\"}'.you can omit outer {} and double quote. e.g 'q:#nodejs,lang:ja' "]
	e:["depth","outputs default format(Util.inspect). default depth is 0 or 1(if result is array or few). you can add depth by this option e.g -i 2."]
	j:["jsonpath","outputs JSON format.filters by given JSONPath. you can specify multiple like -j '$.id|$.name'.output will be 2 dimention array in this case. about JSONPath, see #{JSONPathUrl}"]
	J:["jsonpath","outputs CSV format(separated by ,) if JSONPath indicate single value, -J output is like a string or value. e.g '$.statuses[0].id' -> 12345689 "]
	l:"compress output JSON to single line"
	r:"removes all return codes from result."
	O:["filename","write results to file (default:stdout)"]
	m:["filename","media file such as jpg/png, you don't need to specify 'media_ids' in -o param. -m option can be specified max 4 times"]
	T:"inject Twitter REST API result JSON from stdin instead of accessing Twitter. you can use JSONPath(-j /-J) to parse it. for reusing result or testing purpose"
	n:"does no not anything. (for checking command/params abbreviation.)"
	c:"verify credentials(for checking communication to Twitter server)"
	i:"set up for specified user"
	I:"initialize all data then setup App key again"

try
	GetOpt.setopt 'h::?::dDu:g:p:o:e::j::J::lrO:m:TnciI'
catch e
	switch e.type
		when 'unknown'
			E "Unknown option:#{e.opt}"
		when 'required'
			E "Required parameter for option:#{e.opt}"
	process.exit(1)

try
	GetOpt.getopt (o,p)->
		switch o
			when 'h','?'
				ctx.command='usage'
				ctx.restCommand=p[0] if p[0] isnt ''
			when 'd'
				ctx.isDebugMode=true
			when 'D'
				ctx.isDebugMode=true
				ctx.isRecipeJsDebugMode=true
			when 'u'
				ctx.userName=p[0].replace /^@/,''
			when 'g'
				ctx.command='GET'
				ctx.restCommand=p[0]
				ctx.isForceExecute=true
			when 'p'
				ctx.command='POST'
				ctx.restCommand=p[0]
				ctx.isForceExecute=true
			when 'O'
				ctx.outputFileName=p[0]
			when 'T'
				ctx.command='inject'
			when 'j'
				ctx.jsonPath=if p[0] isnt '' then p[0] else "$"
			when 'm'
				ctx.uploadFiles=p
			when 'J'
				ctx.jsonPath=if p[0] isnt '' then p[0] else "$"
				ctx.outputCsv=true
			when 'e'
				ctx.inspectDepth=if p[0] isnt '' then Number(p[0]) else ctx.inspectDepth
			when 'r'
				ctx.isRemoveReturnCode=true
			when 'l'
				ctx.outputJsonSeparator=null
			when 'n'
				ctx.isCheckCommand=true
			when 'c'
				ctx.command='GET'
				ctx.restCommand='account/verify_credentials'
				ctx.jsonPath='$.name|$.screen_name|$.location|$.description'
				ctx.outputCsv=true
				E "trying to verify your credential. if you see your info below, It's OK."
			when 'o'
				try
					ctx.restParam=JSON.parse p[0]
				catch e
					D "-o arg looks like not JSON. try to convert '#{p[0]}'"
					j=p[0].trim()

					jb=j.replace /^ *{ *(.+?) *} *$/,"$1"
					D "outer {} removed:'#{jb}'"
					js=jb.split ','
					js=js.map (x)=>x.replace /^ *["']?([^:]+?)["']? *: *['"]?(.+?)['"]? *$/,"\"$1\":\"$2\""
					j="{#{js.join(',')}}"

					D "converterd: #{j}"
					try
						ctx.restParam=JSON.parse j
						D "success: #{JSON.stringify ctx.restParam}"
					catch e
						E "-o invalid parameter. #{j} "
						process.exit 1
			when 'i'
				ctx.command='initUser'
			when 'I'
				ctx.command='initAll'

	if ctx.command is 'auto'
		if GetOpt.params().length > 0
			ctx.restCommand=GetOpt.params()[0]
			D "auto mode.restCommand is '#{ctx.restCommand}'"

	if ctx.command is 'usage'
		if !ctx.restCommand?
			P """
			## Command line
			
			    #{AppName} [-u <username>] <command> [options]
				
			    @PARTPIPE@DESCRIPTION@PARTPIPE@
			    
			    Copyright (C) 2019-@PARTPIPE@|date +%Y;@PARTPIPE@ @kssfilo(https://kanasys.com/gtech/)

			## Options

			#{GetOpt.getHelp optUsages}		

			## Examples

			### tweet
			
			    $ #{AppName} -u @yourtwitterid statuses/update -o '{"status":"Hello from #{PackageName}!"}'
			    
			or (abbreviation)
			    
			    $ #{AppName} -u yourtwitterid s/up -o 's:Hello from #{PackageName}!'
			    
			or (environment variable+abbreviation)
			    
			    $ export TWITTER_USER=yourtwitterid
			    $ #{AppName} s/up -o 's:Hello from #{PackageName}!'

			### tweet with jpg/png
			
			    $ #{AppName} s/up -o 's_n:Photo from #{PackageName}!' -m photo.jpg

			### search and print CSV by JSONPath
			
			    $ #{AppName} s/t -o 'q:#nodejs (awesome OR nice)' -rJ $.statuses[*].text

			### checking timeline and JSON output by JSONPath
			
			    $ #{AppName} s/h -rJ '$[*].user.name|$[*].text'
			    #you can chain JSONPath by '|'
				
			about JSONPath see #{JSONPathUrl} for more informaton. 

			you should combine with [norl](https://www.npmjs.com/package/norl) to do more complex JSON processing.

			## Setup
			
			    $ #{AppName} -I
			
			then 
				
			    $ #{AppName} -u @username -i

			## Commands (abbreviation)
			
			```
			#{getCommandList(TwitterDoc,160)}```

			you can see details by \`$ #{AppName} -h <command or abbreviation>\`

			also refer https://developer.twitter.com/en/docs/api-reference-index

			(for using other commands such as Premium/Enterprise search, you can use -g -p option to avoid command / param check.)
			"""
		else
			c=resolveAbbreviation ctx.restCommand,'/',Object.keys(TwitterDoc),false
			P """

			# #{c} (#{findShortestAbbreviation c,Object.keys(TwitterDoc),'/'})

			#{TwitterDoc[c]?.description}
			
			## params (abbreviation)
			
			#{getParamsList(c,TwitterDoc)}
			
			## refer
			
			#{TwitterDoc[c]?.url}

			"""

		process.exit 0

	D "==starting #{AppName}"
	D "-options"
	D "#{JSON.stringify ctx,null,2}"
	D "-------"
	D "sanity checking.."

	throw "you must specify your user name like '-u @username or -u username' or export TWITTER_USER=username" if (!ctx.userName? or ctx.userName=='') and !(ctx.command in ['initAll','inject','nothing']) and !ctx.isCheckCommand


	# E  "warning:you may have to pass parameters as JSON by -o option.  e.g. -o '{\"screen_name\":\"nodejs\"}' to suppress this warning. supply -o {} " if ctx.command in ['get','post'] and !ctx.restParam?
	if ctx.restCommand?
		ctx.restCommand=resolveAbbreviation ctx.restCommand,'/',Object.keys(TwitterDoc)
		if ctx.command is 'auto'
			commandWithoutId=resolveAbbreviation ctx.restCommand,'/',Object.keys(TwitterDoc),false
			ctx.command=TwitterDoc[commandWithoutId].method
			if ctx.command not in ['GET','POST']
				throw "sorry, couldn't guessed method(GET/POST) for this command. use -g or -p"
			D "guessed method is #{ctx.command}"

	if ctx.restParam?
		candiates=(i.name for i in TwitterDoc[ctx.restCommand]?.params ? [])
		for k in Object.keys ctx.restParam
			a=resolveAbbreviation k,'_',candiates
			if a isnt k
				ctx.restParam[a]=ctx.restParam[k]
				delete ctx.restParam[k]

	if ctx.uploadFiles.length >0
		#for v,k of ctx.restParam
		throw "-m is specified to upload media files but no -o option. e.g. '$ #{AppName} s/up -m media.jpg -o 's:Hello'" if !ctx.restParam?

		for i in ctx.uploadFiles
			unless i.match /(jpeg|jpg|png)$/i
				throw "sorry, only support jpeg/png yet'
			unless Fs.existsSync i
				throw "#{i} doesn't exist"

		if ctx.restParam.media_ids?
			E "Warning:you don't need to specify 'media_ids' in -o option. overriding."

		ctx.restParam.media_ids="@MEDIAIDS@"

	D "..OK"

	if ctx.isCheckCommand or ctx.isDebugMode
		E "command:#{ctx.restCommand}" if ctx.restCommand?
		E "method:#{ctx.command}" if ctx.restCommand?
		E "params:#{JSON.stringify ctx.restParam}" if ctx.restParam?

	if ctx.isCheckCommand
		E "check:pass."
		process.exit 0

catch e
	E e
	process.exit 1

$=new RecipeNodeJs
	cacheId:AppName
	traceEnabled:ctx.isRecipeJsDebugMode
	debugEnabled:ctx.isRecipeJsDebugMode


# OAUTH

$.set 'endPoint','https://api.twitter.com/oauth'

$.R 'consumerKeys',(g,t)=>
	new Promise (ok,ng)=>
		rl=require('readline').createInterface {input:process.stdin}

		P "welcome to #{PackageName}. before using this tool, you have to get 'Consumer API keys'(aka.App key) from Twitter app dashboard."
		P ""
		P "https://developer.twitter.com/en/docs/basics/apps/guides/the-app-management-dashboard.html"
		P ""
		P "visit url above and create a new app by Twitter app dashboard. then details->Key and Tokens to see your Consumer API key."
		P ""
		P "1st,copy and paste Consumer API key(API key) to here:"
		state=1
		consumer_key=null
		consumer_secret=null

		rl.on 'line',(l)=>
			l=l.trim()
			return if l.length is 0

			switch state
				when 1
					consumer_key=l
					state=2
					P "next,copy and paste Consumer API key(API secret key) to here:"
				when 2
					consumer_secret=l
					P "API key:#{consumer_key}, API secret key:#{consumer_secret}"
					P "is it ok? [y/n]"
					state=3
				when 3
					if l isnt 'y'
						state=1
						P "copy and paste Consumer API key(API key) to here:"
						return
					else
						P "thank you. Consumer API key has saved to ~/.recipe-js/#{AppName}.json. you can reset it by -I option."
						rl.close()
						ok $.cache t.target,{consumer_key:consumer_key,consumer_secret:consumer_secret},null

$.R 'accessTokens-%',['consumerKeys','endPoint'],(g,t)=>
	new Promise (ok,err)=>
		{OAuth}=require 'oauth'
		oa=new OAuth "#{g.endPoint}/request_token",
			"#{g.endPoint}/access_token",
			g[0].consumer_key,
			g[0].consumer_secret,
			"1.0",
			"oob",
			"HMAC-SHA1"

		oa.getOAuthRequestToken (error,oauth_token,oauth_token_secret,results)=>
			if error
				err error
				return

			authUrl="#{g.endPoint}/authenticate?oauth_token=#{oauth_token}"
			D "oauth_token:#{oauth_token}"
			D "oauth_token_secret:#{oauth_token_secret}"
			D "request token results:#{JSON.stringify results}"
			P "open the url below by a browser and authorize this app for user #{ctx.userName}"
			P ""
			P authUrl
			P ""
			P "then paste the PIN code here:"

			rl=require('readline').createInterface {input:process.stdin}
			rl.on 'line',(l)=>
				unless l.match /^[0-9]+$/
					P "invalid PIN code. PIN is like 12345678:"
					return

				oauth_verifier=l.replace(/[\n\r]/g,'')
				D "oauth_verifier:#{oauth_verifier}"

				oa.getOAuthAccessToken oauth_token,oauth_token_secret,oauth_verifier,(error,oauth_access_token,oauth_access_token_secret,results2)=>
					if error
						E error
						return

					D "oauth_access_token:#{oauth_access_token}"
					D "oauth_token_secret:#{oauth_access_token_secret}"
					D "access token results:#{JSON.stringify results2}"
					D "checking user id.."
					requestedUserId=t.target.replace /accessTokens-/,''
					if results2.screen_name isnt requestedUserId
						err "username is not idential:request=[#{requestedUserId}],actual=[#{results2.screen_name}]"
						return
					
					P "OK.saving access_token_secret into ~/.recipe-js/#{AppName}.json you can reset it by -i option."
					ok $.cache t.target,{oauth_access_token,oauth_access_token_secret},null
					rl.close()

$.R 'twitterClient-%',['consumerKeys','accessTokens-%'],(g,t)=>
	D "setting up twitter object"
	D "consumer_key:#{g[0].consumer_key}"
	#D "consumer_secret:#{g[0].consumer_secret}"
	D "oauth_access_token:#{g[1].oauth_access_token}"
	#D "oauth_access_token_secret:#{g[1].oauth_access_token_secret}"
	Twitter=require 'twitter'

	twitter=new Twitter
		consumer_key:g[0].consumer_key
		consumer_secret:g[0].consumer_secret
		access_token_key:g[1].oauth_access_token
		access_token_secret:g[1].oauth_access_token_secret

	return twitter

# Media Uplorder

$.R 'twitterClient',"twitterClient-#{ctx.userName}",(x)=>x

$.F '(?!@mediaid-).*\.(jpeg|jpg|png|JPEG|JPG|PNG)','binary'

$.R '@mediaid-(.*)',['twitterClient','%'],(g,t)=>
	new Promise (ok,ng)=>
		D "getting media id:file=#{t.deps[1]},length=#{g[1].length}bytes"
		T=g[0]
		T.post 'media/upload',{media:g[1]},(e,m,r)=>
			if e
				ng(e)
				return
			D "upload success:#{JSON.stringify m}"
			ok(m?.media_id_string)

$.R 'mediaids',ctx.uploadFiles.map((x)=>"@mediaid-#{x}"),(gs)=>
	D "finished to get media ids #{JSON.stringify gs}"
	return gs.join(',')

###
$.make 'mediaids'
.then (mediaids)=>
	D "FINISH #{JSON.stringify mediaids}"
	process.exit 1
.catch (e)=>
	E e
	process.exit 1
###

# Main

try
	restCallback=(e,r,s)=>
		D 'response'
		if e
			E e
			process.exit 1

		try
			if ctx.isRemoveReturnCode
				removeReturnCodeFromString=(obj,idx)=>
					if typeof(obj[idx]) is 'string'
						obj[idx]=obj[idx].replace /\n/gm,""
				f=(obj)=>
					if typeof(obj) is 'object'
						if Array.isArray obj
							for v,i in obj
								if typeof(v) is 'object'
									f(v)
								else
									removeReturnCodeFromString obj,i
						else
							for k,v of obj
								if typeof(v) is 'object'
									f(v)
								else
									removeReturnCodeFromString obj,k
				f(r)

			if ctx.jsonPath?
				{JSONPath}=require 'jsonpath-plus'

				splited=ctx.jsonPath.split '|'

				D "JSONPathes:JSON.stringify #{splited}"

				if splited.length > 1 or ctx.outputCsv
					rs=[]
					for i in splited
						p=JSONPath
							path:i
							json:r
							wrap:true
						D "apply:#{i} ->"

						rs.push p

					firstCount=rs[0].length
					for i,idx in rs
						if i.length isnt firstCount
							E "Warning:#{idx}th result length is not same as 1st result"
						if ctx.outputCsv
							# D "converting boolean to string to convert to CSV"
							for j,idx in i
								# D "#{j},#{idx}"
								if typeof(j) == 'boolean'
									# D "boolean found"
									i[idx]=if j then 'true' else 'false'

					r=_.zip.apply null, rs

					if ctx.outputCsv and Array.isArray r
						D "converting array to csv.."
						{convertArrayToCSV}=require('convert-array-to-csv')
						r=convertArrayToCSV(r)
				else
					p=JSONPath
						path:ctx.jsonPath
						json:r
						wrap:true
					D "apply:#{ctx.jsonPath} ->"
					r=p
			else
				adjust=0
				adjust=1 if Array.isArray(r) or Object.keys(r).length < ctx.inspectAdjustCount
				r=Util.inspect(r,false,ctx.inspectDepth+adjust)
				E "tips: some objects are folded. you can increase inspect depth by -e option. e.g. -e 2 , or use JSONPath(-j / -J )" if r.match('[Object]')
		catch e
			E e
			process.exit 1

		result=''
		if typeof(r) is 'object'
			D 'result type is object'
			result=JSON.stringify r,null,ctx.outputJsonSeparator
		else
			D 'result type is string or value'
			result=r

		if typeof(ctx.outputFileName) is 'string'
			Fs.writeFileSync ctx.outputFileName,result
		else
			P result.trim()

	switch ctx.command
		when 'nothing'
			true

		when 'inject'
			injectData=JSON.parse Fs.readFileSync('/dev/stdin', 'utf8')
			restCallback null,injectData,{}

		when 'GET','POST'
			proc=Promise.resolve()

			if ctx.uploadFiles.length > 0
				D "uploading files ..#{ctx.uploadFiles}"
				proc=proc.then ()=>
					$.make 'mediaids'
				.then (mediaids)=>
					ctx.mediaIds=mediaids

			proc.then ()=>
				$.make "twitterClient"
			.then (T)=>
				#D "#{JSON.stringify T}"
				D "rest command:#{ctx.restCommand}"
				D "rest param:#{JSON.stringify ctx.restParam}"

				for k,v of ctx.restParam
					if v is '@MEDIAIDS@'
						D 'found @MEDIAIDS@ in rest param.replace to actual media ids'

						unless ctx.mediaIds?
							throw '@MEDIAIDS@ specified but no -m option'

						ctx.restParam[k]=ctx.mediaIds

				switch ctx.command
					when 'GET'
						T.get ctx.restCommand,ctx.restParam ? {},restCallback
					when 'POST'
						T.post ctx.restCommand,ctx.restParam ? {},restCallback
			.catch (e)=>
				E e

		when 'initUser'
			$.clearCache "accessTokens-#{ctx.userName}"
			$.remake "accessTokens-#{ctx.userName}"
			.catch (e)=>
				E e

		when 'initAll'
			$.clearCache()
			$.remake "consumerKeys"
			.catch (e)=>
				E e

catch e
	E e


