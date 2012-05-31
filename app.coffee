process.env.NODE_ENV ?= 'dev'

util = require 'util'
express = require 'express'
config = require 'nconf'
junction = require 'junction'
ping = require 'junction-ping'

config.env().file(file: 'config.json')

xmppOptions =
	type: 'client'
	jid: config.get 'xmppUser'
	password: config.get 'xmppPassword'

app = express.createServer()
io = require('socket.io').listen(app)
client = junction.create()

app.set 'view options',
	layout: false

app.configure 'dev', ->
	app.use express.logger('dev')
	io.set 'log level', 2
	client.use junction.dump()
	client.use junction.errorHandler({ showStack: true, dumpExceptions: true })

app.configure 'production', ->
	app.use express.logger()
	io.set 'log level', 1
	io.enable 'browser client minification'
	io.enable 'browser client etag'
	io.enable 'browser client gzip'
	client.use junction.errorHandler()

app.configure ->
	app.use express.responseTime()
	app.use require('connect-assets')()
	app.use express.static(__dirname + '/public')

client.use ping()

client.use junction.presenceParser()
client.use junction.presence (handler) ->
	broadcastHandler = (stanza) ->
		io.sockets.emit 'xmpp:received',
			name: stanza.name
			from: stanza.attrs.from
			to: stanza.attrs.to
			id: stanza.attrs.id
			priority: stanza.priority
			type: stanza.attrs.type or stanza.show
			status: stanza.status

	handler.on 'available', broadcastHandler
	handler.on 'unavailable', broadcastHandler
	handler.on 'err', broadcastHandler

client.use junction.messageParser()
client.use junction.message (handler) ->
	broadcastHandler = (stanza) ->
		io.sockets.emit 'xmpp:received',
			name: stanza.name
			from: stanza.attrs.from
			to: stanza.attrs.to
			id: stanza.attrs.id
			type: stanza.attrs.type
			body: stanza.body

	handler.on 'chat', broadcastHandler
	handler.on 'groupchat', broadcastHandler
	handler.on 'err', broadcastHandler
	handler.on 'headline', broadcastHandler
	handler.on 'normal', broadcastHandler

client.use junction.serviceUnavailable()

app.get '/', (req, res) ->
	res.render("index.jade")

io.on 'connection', (socket) ->
	socket.on 'join', (room, nick, callback) ->
		if not connection then return callback "Not connected"
		if nick then room = room + '/' + nick
		connection.send new junction.elements.Presence(room)
		callback()

connection = client.connect(xmppOptions).on 'online', ->
	console.log 'Connected as: ' + @jid
	@send new junction.elements.Presence()

app.listen process.env.PORT || 1337, ->
	util.log util.format "[%s] http://%s:%d/", process.env.NODE_ENV, app.address().address, app.address().port

