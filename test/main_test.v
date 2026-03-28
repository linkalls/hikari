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
