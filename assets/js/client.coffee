$ ->
	req = $.get '/api/test', (data) ->
		if data.err
			console.error data.err
			$('#output').empty().append data.err
		$('#output').empty().append data.msg
