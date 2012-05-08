process.env.NODE_ENV ?= 'dev'

util = require 'util'
express = require 'express'

app = express.createServer()

app.set 'view options',
	layout: false

app.configure 'dev', ->
	app.use express.logger('dev')

app.configure 'production', ->
	app.use express.logger()

app.configure ->
	app.use express.responseTime()
	app.use require('connect-assets')()
	app.use express.static(__dirname + '/public')

app.get '/', (req, res) ->
	res.render("index.jade")

app.get '/api/test', (req, res) ->
	res.json {err: false, msg: "API speaks!"}

app.listen process.env.PORT || 1337, ->
	util.log util.format "[%s] Listening on port: %d", process.env.NODE_ENV, app.address().port
