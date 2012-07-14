socket = io.connect '/'
r = []
$ ->
	$(document).ready ->
		socket.emit 'roster', 'stuff', updateRoster

	$('#rooms').change ->
		show = $('#rooms').val()
		if show isnt "Rooms"
			for room in r
				$('#r'+ r.indexOf room).attr 'class', 'invisible'
				$('#o'+ r.indexOf room).attr 'class', 'invisible'
			$('#r' + r.indexOf show).attr 'class', 'visible'
			$('#o' + r.indexOf show).attr 'class', 'visible'

	updateRoster = (err,rooms) ->
		for own room of rooms
			if rooms[room].name not in r
				r.push rooms[room].name
				num = parseInt(r.length - 1)
				$('#rooms').append $('<option>').text rooms[room].name
				$('#output').append $('<div>').attr 'id', 'o' + num
				$('#roster').append $('<div>').attr 'id', 'r' + num
			data = '<b>' + rooms[room].name + '</b>'
			for own people of rooms[room].roster
				data += '<br>' + rooms[room].roster[people]
				num = parseInt(r.length - 1)
				$('#r'+num).html data

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
		if room not in r
			r.push room
			$('#rooms').append $('<option>').text room
			$('#output').append $('<div>').attr 'id', 'o'+r.indexOf room
			$('#roster').append $('<div>').attr 'id', 'r'+r.indexOf room
			$('#rooms').val room
			show = $('#rooms').val()
			for room in r
				$('#r'+ r.indexOf room).attr 'class', 'invisible'
				$('#o'+ r.indexOf room).attr 'class', 'invisible'
			$('#r' + r.indexOf show).attr 'class', 'visible'
			$('#o' + r.indexOf show).attr 'class', 'visible'
			
		socket.emit 'roster', 'stuff', updateRoster

	$('#btnSend').click ->
		socket.emit 'msg', $('#rooms').val(), $('#txtMsg').val();
		$('#txtMsg').val ''

	socket.on 'xmpp:received', (stanza) ->
		console.log "Received", stanza
		switch stanza.name
			when 'presence'
				$('#o'+r.indexOf stanza.room).append $('<div>').text "#{stanza.from} is #{stanza.type}"
				socket.emit 'roster', 'stuff', updateRoster
			when 'message'
				if stanza.body
					$('#o'+r.indexOf stanza.room).append $('<div>').text "<#{stanza.from}> #{stanza.body}"
			else
				console.error "unrecognized stanza", stanza
		$('#output').animate({scrollTop: $('#output')[0].scrollHeight});

