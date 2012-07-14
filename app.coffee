process.env.NODE_ENV ?= 'dev'

util = require 'util'
express = require 'express'
config = require 'nconf'
junction = require 'junction'
ping = require 'junction-ping'
rooms = {}

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

	mucPresenceHandler = (p) ->

		room = p.from.split("/")[0]
		nick = p.from.split("/")[1]

		return true if room not of rooms

		statusElems = p.status
		if statusElems
			statusCodes = (parseInt(s.code) for s in statusElems)
		else
			statusCodes = '0'

		if statusCodes.indexOf(110) >= 0 and p.type isnt 'unavailable'
		        rooms[room].joined = true
		else if not rooms[room].joined and p.type isnt 'unavailable'
		        rooms[room].roster.push nick
		        return true

		if p.type is 'unavailable'
		        i = rooms[room].roster.indexOf nick
		        rooms[room].roster.splice(i, 1) if i isnt -1
			

		        if rooms[room].nick is nick and statusCodes.indexOf(303) < 0
		                delete rooms[room]

		        else if statusCodes.indexOf(303) >= 0
		                itemElem = p.item[0]
		                newNick = itemElem.nick
		                rooms[room].roster.push newNick

		else if rooms[room].roster.indexOf(nick) is -1
		        rooms[room].roster.push nick
		        $(xmpp).triggerHandler 'joined',
		                room: room
		                nick: nick

		true

	broadcastHandler = (stanza) ->
		mucPresenceHandler stanza
		io.sockets.emit 'xmpp:received',
			name: stanza.name
			from: stanza.attrs.from
			room: stanza.from.split("/")[0]
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
			room: stanza.from.split("/")[0]
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
		rooms[room.split("/")[0]] = 
			name: room.split("/")[0]
			nick: nick
			roster: []
		callback()
	socket.on 'roster', (r, callback) ->
		callback?(null, rooms)
		
	socket.on 'msg', (to,msg) ->
		smsg = new junction.elements.Message(to, null, 'groupchat');
		smsg.c('body', {}).t(msg);
		connection.send smsg

connection = client.connect(xmppOptions).on 'online', ->
	console.log 'Connected as: ' + @jid
	@send new junction.elements.Presence()


app.listen process.env.PORT || 1337, ->
	util.log util.format "[%s] http://%s:%d/", process.env.NODE_ENV, app.address().address, app.address().port

