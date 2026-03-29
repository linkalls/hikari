module main

import hikari
import picohttpparser
import time

// テスト: カスタム 404 ハンドラー
fn test_custom_not_found_handler() {
	mut app := hikari.new()
	app.set_not_found_handler(fn (mut ctx hikari.Context) !hikari.Response {
		return ctx.json_status(404, {
			'error': 'Not Found'
			'path':  ctx.req.path
		})
	})

	app.get('/exists', fn (mut ctx hikari.Context) !hikari.Response {
		return ctx.text('found')
	})

	// 存在するルートは通常通りに返す
	mut ctx_ok := hikari.Context{
		req:    picohttpparser.Request{
			method: 'GET'
			path:   '/exists'
		}
		params: map[string]string{}
	}
	res_ok := app.handle_request(mut ctx_ok) or { panic(err) }
	assert res_ok.status == 200
	assert res_ok.body == 'found'

	// 存在しないルートはカスタムハンドラーが返す
	mut ctx_notfound := hikari.Context{
		req:    picohttpparser.Request{
			method: 'GET'
			path:   '/missing'
		}
		params: map[string]string{}
	}
	res_notfound := app.handle_request(mut ctx_notfound) or { panic(err) }
	assert res_notfound.status == 404
	assert res_notfound.headers['Content-Type'] == 'application/json; charset=utf-8'
}

// テスト: ctx.json_status() メソッド
fn test_json_status() {
	mut app := hikari.new()
	app.post('/resource', fn (mut ctx hikari.Context) !hikari.Response {
		return ctx.json_status(201, {
			'id':   '1'
			'name': 'Resource'
		})
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
	assert res.headers['Content-Type'] == 'application/json; charset=utf-8'
	assert res.body.contains('Resource')
}

// テスト: ctx.html_status() メソッド
fn test_html_status() {
	mut app := hikari.new()
	app.get('/custom', fn (mut ctx hikari.Context) !hikari.Response {
		return ctx.html_status(202, '<p>Accepted</p>')
	})

	mut ctx := hikari.Context{
		req:    picohttpparser.Request{
			method: 'GET'
			path:   '/custom'
		}
		params: map[string]string{}
	}
	res := app.handle_request(mut ctx) or { panic(err) }
	assert res.status == 202
	assert res.headers['Content-Type'] == 'text/html; charset=utf-8'
	assert res.body == '<p>Accepted</p>'
}

// テスト: タイムアウトミドルウェア（タイムアウトしない正常ケース）
fn test_timeout_middleware_ok() {
	mut app := hikari.new()
	app.use(hikari.timeout(hikari.TimeoutOptions{
		timeout_ms: 5000
	}))

	app.get('/', fn (mut ctx hikari.Context) !hikari.Response {
		return ctx.text('ok')
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
	assert res.body == 'ok'
}

// テスト: タイムアウトミドルウェア（タイムアウト発生ケース）
fn test_timeout_middleware_exceeded() {
	mut app := hikari.new()
	app.use(hikari.timeout(hikari.TimeoutOptions{
		// 0ms タイムアウト（即座にタイムアウト）
		timeout_ms: 0
		message:    'Timeout!'
	}))

	app.get('/slow', fn (mut ctx hikari.Context) !hikari.Response {
		time.sleep(time.millisecond)
		return ctx.text('done')
	})

	mut ctx := hikari.Context{
		req:    picohttpparser.Request{
			method: 'GET'
			path:   '/slow'
		}
		params: map[string]string{}
	}
	res := app.handle_request(mut ctx) or { panic(err) }
	assert res.status == 408
	assert res.body == 'Timeout!'
}

// テスト: ミドルウェアなしの直接ハンドラー呼び出し（パフォーマンス最適化）
fn test_direct_handler_no_middleware() {
	mut app := hikari.new()
	// ミドルウェアを一切追加しない
	app.get('/fast', fn (mut ctx hikari.Context) !hikari.Response {
		return ctx.text('direct')
	})

	mut ctx := hikari.Context{
		req:    picohttpparser.Request{
			method: 'GET'
			path:   '/fast'
		}
		params: map[string]string{}
	}
	res := app.handle_request(mut ctx) or { panic(err) }
	assert res.status == 200
	assert res.body == 'direct'
}
