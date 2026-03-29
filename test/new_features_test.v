module main

import hikari
import picohttpparser

// テスト: ctx.redirect() メソッド
fn test_redirect() {
	mut app := hikari.new()
	app.get('/old', fn (mut ctx hikari.Context) !hikari.Response {
		return ctx.redirect('/new', 302)
	})

	mut ctx := hikari.Context{
		req:    picohttpparser.Request{
			method: 'GET'
			path:   '/old'
		}
		params: map[string]string{}
	}
	res := app.handle_request(mut ctx) or { panic(err) }
	assert res.status == 302
	assert res.headers['Location'] == '/new'
}

// テスト: ctx.set() / ctx.get() コンテキストストア
fn test_context_store() {
	mut app := hikari.new()

	app.get('/profile', fn (mut ctx hikari.Context) !hikari.Response {
		user_id := ctx.get('user_id')
		return ctx.text('User: ${user_id}')
	}, fn (mut ctx hikari.Context, next hikari.Next) !hikari.Response {
		ctx.set('user_id', '42')
		return next(mut ctx)
	})

	mut ctx := hikari.Context{
		req:    picohttpparser.Request{
			method: 'GET'
			path:   '/profile'
		}
		params: map[string]string{}
	}
	res := app.handle_request(mut ctx) or { panic(err) }
	assert res.status == 200
	assert res.body == 'User: 42'
}

// テスト: HEAD メソッドのサポート（GET ルートへのフォールバック）
fn test_head_method() {
	mut app := hikari.new()
	app.get('/resource', fn (mut ctx hikari.Context) !hikari.Response {
		return ctx.text('resource body')
	})

	mut ctx := hikari.Context{
		req:    picohttpparser.Request{
			method: 'HEAD'
			path:   '/resource'
		}
		params: map[string]string{}
	}
	res := app.handle_request(mut ctx) or { panic(err) }
	assert res.status == 200
	// HEAD レスポンスはボディを持たない
	assert res.body == ''
}

// テスト: ルートグループ
fn test_route_group() {
	mut app := hikari.new()
	mut api := app.group('/api/v1')

	api.get('/users', fn (mut ctx hikari.Context) !hikari.Response {
		return ctx.text('users list')
	})
	api.post('/users', fn (mut ctx hikari.Context) !hikari.Response {
		return ctx.text('user created')
	})

	mut ctx_get := hikari.Context{
		req:    picohttpparser.Request{
			method: 'GET'
			path:   '/api/v1/users'
		}
		params: map[string]string{}
	}
	res_get := app.handle_request(mut ctx_get) or { panic(err) }
	assert res_get.status == 200
	assert res_get.body == 'users list'

	mut ctx_post := hikari.Context{
		req:    picohttpparser.Request{
			method: 'POST'
			path:   '/api/v1/users'
		}
		params: map[string]string{}
	}
	res_post := app.handle_request(mut ctx_post) or { panic(err) }
	assert res_post.status == 200
	assert res_post.body == 'user created'
}

// テスト: HttpError 型のサポート
fn test_http_error() {
	mut app := hikari.new()
	app.get('/forbidden', fn (mut ctx hikari.Context) !hikari.Response {
		return hikari.http_error(403, 'Access Denied')
	})

	mut ctx := hikari.Context{
		req:    picohttpparser.Request{
			method: 'GET'
			path:   '/forbidden'
		}
		params: map[string]string{}
	}
	res := app.handle_request(mut ctx) or { panic(err) }
	assert res.status == 403
	assert res.body == 'Access Denied'
}

// テスト: ctx.send_status() メソッド
fn test_send_status() {
	mut app := hikari.new()
	app.post('/resource', fn (mut ctx hikari.Context) !hikari.Response {
		return ctx.send_status(201, 'Created')
	})

	mut ctx := hikari.Context{
		req:    picohttpparser.Request{
			method: 'POST'
			path:   '/resource'
		}
		params: map[string]string{}
	}
	res := app.handle_request(mut ctx) or { panic(err) }
	assert res.status == 201
	assert res.body == 'Created'
}

// テスト: URL エンコードフォームのパース
fn test_url_encoded_form() {
	mut app := hikari.new()
	app.post('/login', fn (mut ctx hikari.Context) !hikari.Response {
		username := ctx.form_value('username')
		password := ctx.form_value('password')
		assert username == 'admin'
		assert password == 'secret'
		return ctx.text('ok')
	})

	mut ctx := hikari.Context{
		req:    picohttpparser.Request{
			method: 'POST'
			path:   '/login'
			body:   'username=admin&password=secret'
		}
		params:  map[string]string{}
		headers: map[string]string{}
	}
	ctx.headers['Content-Type'] = 'application/x-www-form-urlencoded'
	res := app.handle_request(mut ctx) or { panic(err) }
	assert res.status == 200
	assert res.body == 'ok'
}
