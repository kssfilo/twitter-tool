#!/usr/bin/env coffee
GetOpt=require '@kssfilo/getopt'
Fs=require 'fs'
Path=require 'path'
{RecipeNodeJs}=require 'recipe-js'
_=require 'lodash'

AppName="twitter"

P=console.log
E=console.error
D=(str)=>
	E "#{AppName}:"+str if ctx.isDebugMode

ctx={
	isDebugMode:false
	isRecipeJsDebugMode:false
	userName:process?.env['TWITTER_USER'] ? null
	command:'usage'
	restParam:null
	outputJsonSeparator:"\t"
	jsonPath:null
	outputCsv:false
	outputFileName:null
	uploadFiles:[]
}

optUsages=
	h:"help"
	d:"debug mode"
	D:"debug mode (+ recipe-js debug messages)"
	u:["username","specify your user name like @username or username. you can set default by TWITTER_USER environment variable "]
	g:["command","GET request.command is Twitter REST Api command. e.g. 'search/tweets'"]
	p:["command","POST request."]
	o:["jsonstring","parameters for GET/POST request. JSON format like '{\"q\":\"#nodejs\"}'.you can omit outer {} and double quote. e.g 'q:#nodejs,lang:ja' "]
	j:["jsonpath","filters output by given JSONPath. you can specify multiple like -j '$.id|$.name'.output will be 2 dimention array in this case. about JSONPath, see https://goessner.net/articles/JsonPath/"]
	J:["jsonpath","same as -j but CSV output(separated by ,) if JSONPath indicate single value, -J output is like a string or value. e.g '$.statuses[0].id' -> 12345689 "]
	l:"compress output JSON to single line"
	O:["filename","write results to file (default:stdout)"]
	m:["filename","media file such as jpg/png,  you can refer media ids like -o 'status:photo,media_ids:@MEDIAIDS@'. -m option can be specified max 4 times"]
	T:"inject Twitter REST API result from stdin instead of accessing Twitter. you can use JSONPath(-j /-J) to parse it. for reusing result or testing purpose"
	i:"set up for specified user"
	I:"initialize all data then setup App key again"

try
	GetOpt.setopt 'h?dDu:g:p:o:j:J:lO:m:TiI'
catch e
	switch e.type
		when 'unknown'
			E "Unknown option:#{e.opt}"
		when 'required'
			E "Required parameter for option:#{e.opt}"
	process.exit(1)

GetOpt.getopt (o,p)->
	switch o
		when 'h','?'
			ctx.command='usage'
		when 'd'
			ctx.isDebugMode=true
		when 'D'
			ctx.isDebugMode=true
			ctx.isRecipeJsDebugMode=true
		when 'u'
			ctx.userName=p[0].replace /^@/,''
		when 'g'
			ctx.command='get'
			ctx.restCommand=p[0]
		when 'p'
			ctx.command='post'
			ctx.restCommand=p[0]
		when 'O'
			ctx.outputFileName=p[0]
		when 'T'
			ctx.command='inject'
		when 'j'
			ctx.jsonPath=p[0]
		when 'm'
			ctx.uploadFiles=p
		when 'J'
			ctx.jsonPath=p[0]
			ctx.outputCsv=true
		when 'l'
			ctx.outputJsonSeparator=null
		when 'o'
			try
				j=p[0].trim()
				unless j.match /^{.+}$/    #q:value,v:value...
					D "-o arg look like not JSON yet. try to convert '#{j}'"
					js=j.split ','
					js=js.map (x)=>x.replace /^"?([^:]+?)"?:"?(.+?)"?$/,"\"$1\":\"$2\""
					j="{#{js.join(',')}}"
					D "converterd: #{j}"
				ctx.restParam=JSON.parse j
				D "param: #{JSON.stringify ctx.restParam}"
			catch e
				E e.toString()
				process.exit 1
		when 'i'
			ctx.command='initUser'
		when 'I'
			ctx.command='initAll'

if ctx.command is 'usage'
	P """
	## Command line
	
	#{AppName} -u <username> [options]

	## Options

	#{GetOpt.getHelp optUsages}		
	
	## Examples
	
	    $ #{AppName} -u @yourtwitterid -g statuses/user_timeline -o '{"screen_name":"nodejs"}'
	
	## Setup
	
	    $ #{AppName} -I
	    
	    then 
	    
	    $ #{AppName} -u @username -i
	"""
	process.exit 0

D "==starting #{AppName}"
D "-options"
D "#{JSON.stringify ctx,null,2}"
D "-------"
D "sanity checking.."
try
	throw "you must specify your user name like '-u @username or -u username' or TWITTER_USER env" if (!ctx.userName? or ctx.userName=='') and !(ctx.command in ['initAll','inject'])
	for i in ctx.uploadFiles
		unless i.match /(jpeg|jpg|png)$/i
			throw "sorry, only support jpeg/png yet'
		unless Fs.existsSync i
			throw "#{i} doesn't exist"

	# E  "warning:you may have to pass parameters as JSON by -o option.  e.g. -o '{\"screen_name\":\"nodejs\"}' to suppress this warning. supply -o {} " if ctx.command in ['get','post'] and !ctx.restParam?

	D "..OK"
catch e
	E e.toString()
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

		P "welcome to cli-twitter. before using this tool, you have to get 'Consumer API keys'(aka.App key) from Twitter app dashboard."
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
			D "reques token results:#{JSON.stringify results}"
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
	D "consumer_secret:#{g[0].consumer_secret}"
	D "oauth_access_token:#{g[1].oauth_access_token}"
	D "oauth_access_token_secret:#{g[1].oauth_access_token_secret}"
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
	E e.toString()
	process.exit 1
###

# Main

try
	restCallback=(e,r,s)=>
		D 'response'
		if e
			E JSON.stringify e
			process.exit 1

		try
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

		catch e
			E e.toString()
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

		when 'get','post'
			proc=Promise.resolve()

			if ctx.uploadFiles.length > 0
				D "uploading files ..#{ctx.uploadFiles}"
				proc=proc.then ()=>
					$.make 'mediaids'
				.then (mediaids)=>
					ctx.mediaIds=mediaids

			proc.then ()=>
				$.make"twitterClient"
			.then (T)=>
				D "#{JSON.stringify T}"
				D "rest command:#{ctx.restCommand}"
				D "rest param:#{JSON.stringify ctx.restParam}"

				for k,v of ctx.restParam
					if v is '@MEDIAIDS@'
						D 'found @MEDIAIDS@ in rest param.replace to actual media ids'

						unless ctx.mediaIds?
							throw '@MEDIAIDS@ specified but no -m option'

						ctx.restParam[k]=ctx.mediaIds

				switch ctx.command
					when 'get'
						T.get ctx.restCommand,ctx.restParam ? {},restCallback
					when 'post'
						T.post ctx.restCommand,ctx.restParam ? {},restCallback
			.catch (e)=>
				E e.toString()

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
	E e.toString()


