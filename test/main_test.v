module main

import hikari
import json
import picohttpparser

fn test_routing_basic() {
	mut app := hikari.new()
	app.get('/', fn (mut ctx hikari.Context) !hikari.Response {
		return ctx.text('Hello Hikari')
	})

	mut ctx := hikari.Context{
		req:    picohttpparser.Request{
			method: 'GET'
			path:   '/'
		}
		params: map[string]string{}
	}
	res := app.handle_request(mut ctx) or { panic(err) }
	assert res.status == 200
	assert res.body == 'Hello Hikari'
}

fn test_routing_not_found() {
	mut app := hikari.new()
	mut ctx := hikari.Context{
		req:    picohttpparser.Request{
			method: 'GET'
			path:   '/nowhere'
		}
		params: map[string]string{}
	}
	res := app.handle_request(mut ctx) or { panic(err) }
	assert res.status == 404
}

fn test_routing_params() {
	mut app := hikari.new()
	app.get('/users/:id', fn (mut ctx hikari.Context) !hikari.Response {
		id := ctx.param('id')
		return ctx.text('User ID: ${id}')
	})

	mut ctx := hikari.Context{
		req:    picohttpparser.Request{
			method: 'GET'
			path:   '/users/42'
		}
		params: map[string]string{}
	}
	res := app.handle_request(mut ctx) or { panic(err) }
	assert res.status == 200
	assert res.body == 'User ID: 42'
}

struct User {
	name string
	age  int
}

fn test_json_response() {
	mut app := hikari.new()
	app.get('/api/user', fn (mut ctx hikari.Context) !hikari.Response {
		return ctx.json(User{ name: 'Alice', age: 30 })
	})

	mut ctx := hikari.Context{
		req:    picohttpparser.Request{
			method: 'GET'
			path:   '/api/user'
		}
		params: map[string]string{}
	}
	res := app.handle_request(mut ctx) or { panic(err) }
	assert res.status == 200
	assert res.headers['Content-Type'] == 'application/json; charset=utf-8'

	decoded := json.decode(User, res.body) or { panic(err) }
	assert decoded.name == 'Alice'
	assert decoded.age == 30
}

fn test_post_json() {
	mut app := hikari.new()
	app.post('/api/user', fn (mut ctx hikari.Context) !hikari.Response {
		user := ctx.bind_json[User]() or { return error('invalid json') }
		assert user.name == 'Bob'
		assert user.age == 25
		return ctx.text('Created')
	})

	mut ctx := hikari.Context{
		req:    picohttpparser.Request{
			method: 'POST'
			path:   '/api/user'
			body:   '{"name":"Bob","age":25}'
		}
		params: map[string]string{}
	}
	res := app.handle_request(mut ctx) or { panic(err) }
	assert res.status == 200
	assert res.body == 'Created'
}

fn test_error_handler() {
	mut app := hikari.new()
	app.set_error_handler(fn (err IError, mut ctx hikari.Context) !hikari.Response {
		return ctx.text('Custom Error: ${err.msg()}')
	})

	app.get('/error', fn (mut ctx hikari.Context) !hikari.Response {
		return error('Something went wrong')
	})

	mut ctx := hikari.Context{
		req:    picohttpparser.Request{
			method: 'GET'
			path:   '/error'
		}
		params: map[string]string{}
	}
	res := app.handle_request(mut ctx) or { panic(err) }
	assert res.status == 200
	assert res.body == 'Custom Error: Something went wrong'
}

fn test_file_upload() {
	mut app := hikari.new()
	app.post('/upload', fn (mut ctx hikari.Context) !hikari.Response {
		username := ctx.form_value('username')
		assert username == 'testuser'

		file := ctx.file('avatar') or { return ctx.text('no file') }
		assert file.filename == 'avatar.png'
		assert file.content_type == 'image/png'
		assert file.data == 'fake-png-data'

		return ctx.text('uploaded')
	})

	boundary := '----WebKitFormBoundary7MA4YWxkTrZu0gW'
	body := '--${boundary}\r\n' +
		'Content-Disposition: form-data; name="username"\r\n\r\n' +
		'testuser\r\n' +
		'--${boundary}\r\n' +
		'Content-Disposition: form-data; name="avatar"; filename="avatar.png"\r\n' +
		'Content-Type: image/png\r\n\r\n' +
		'fake-png-data\r\n' +
		'--${boundary}--\r\n'

	mut ctx := hikari.Context{
		req:    picohttpparser.Request{
			method: 'POST'
			path:   '/upload'
			body:   body
		}
		params: map[string]string{}
		headers: map[string]string{}
	}
	// For testing, mock context headers directly as Hikari context wrapper parses from it
	ctx.headers['Content-Type'] = 'multipart/form-data; boundary=' + boundary
	res := app.handle_request(mut ctx) or { panic(err) }
	assert res.status == 200
	assert res.body == 'uploaded'
}
