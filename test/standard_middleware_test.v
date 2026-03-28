module main

import hikari
import picohttpparser

fn test_logger_middleware() {
	mut app := hikari.new()
	app.use(hikari.logger())

	app.get('/', fn (mut ctx hikari.Context) !hikari.Response {
		return ctx.text('Hello')
	})

	mut ctx := hikari.Context{
		req: picohttpparser.Request{
			method: 'GET'
			path: '/'
		}
		params: map[string]string{}
	}

	res := app.handle_request(mut ctx) or { panic(err) }
	assert res.status == 200
	assert res.body == 'Hello'
}

fn test_cors_middleware() {
	mut app := hikari.new()
	app.use(hikari.cors(hikari.CorsOptions{
		allow_origins: ['http://localhost']
		allow_methods: ['GET']
	}))

	app.get('/api', fn (mut ctx hikari.Context) !hikari.Response {
		return ctx.text('API data')
	})

	mut req_options := picohttpparser.Request{
		method: 'OPTIONS'
		path: '/api'
		num_headers: 1
	}
	req_options.headers[0] = picohttpparser.Header{
		name: 'Origin'
		value: 'http://localhost'
	}
	mut ctx_options := hikari.Context{
		req: req_options
		params: map[string]string{}
	}

	res_options := app.handle_request(mut ctx_options) or { panic(err) }
	assert res_options.status == 204
	assert res_options.headers['Access-Control-Allow-Origin'] == 'http://localhost'
	assert res_options.headers['Access-Control-Allow-Methods'] == 'GET'

	mut req_get := picohttpparser.Request{
		method: 'GET'
		path: '/api'
		num_headers: 1
	}
	req_get.headers[0] = picohttpparser.Header{
		name: 'Origin'
		value: 'http://localhost'
	}
	mut ctx_get := hikari.Context{
		req: req_get
		params: map[string]string{}
	}

	res_get := app.handle_request(mut ctx_get) or { panic(err) }
	assert res_get.status == 200
	assert res_get.body == 'API data'
	assert res_get.headers['Access-Control-Allow-Origin'] == 'http://localhost'
}

fn test_recover_middleware() {
	mut app := hikari.new()
	app.use(hikari.recover())

	app.get('/panic', fn (mut ctx hikari.Context) !hikari.Response {
		return error('forced error')
	})

	mut ctx := hikari.Context{
		req: picohttpparser.Request{
			method: 'GET'
			path: '/panic'
		}
		params: map[string]string{}
	}

	res := app.handle_request(mut ctx) or { panic(err) }
	assert res.status == 500
	assert res.body == 'Internal Server Error'
}
