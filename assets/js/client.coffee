socket = io.connect '/'

$ ->

	$('.persistent').change (event) ->
		element = event.target
		localStorage.setItem 'field-' + (element.name || element.id), element.value

	$('.persistent').each (index, element) ->
		value = localStorage.getItem 'field-' + (element.name || element.id)
		element.value = value if value

	errorHandlerCallback = (err) ->
		return if not err
		console.error err
		$('#output').append $('<div>').text err

	$('#btnJoin').click ->
		room = $('#txtRoom').val()
		nick = $('#txtNick').val()
		socket.emit 'join', room, nick, errorHandlerCallback

	socket.on 'xmpp:received', (stanza) ->
		console.log "Received", stanza
		switch stanza.name
			when 'presence'
				$('#output').append $('<div>').text "#{stanza.from} is #{stanza.type}"
			when 'message'
				if stanza.body
					$('#output').append $('<div>').text "<#{stanza.from}> #{stanza.body}"
			else
				console.error "unrecognized stanza", stanza

