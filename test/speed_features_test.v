module main

import hikari
import picohttpparser

// テスト: ctx.query_value() クエリパラメータ便利メソッド
fn test_query_value() {
	mut app := hikari.new()
	app.get('/search', fn (mut ctx hikari.Context) !hikari.Response {
		q := ctx.query_value('q')
		page := ctx.query_value('page')
		return ctx.text('q=${q}&page=${page}')
	})

	mut ctx := hikari.Context{
		req:    picohttpparser.Request{
			method: 'GET'
			path:   '/search?q=hello&page=2'
		}
		params: map[string]string{}
	}
	ctx.parse_query()
	res := app.handle_request(mut ctx) or { panic(err) }
	assert res.status == 200
	assert res.body == 'q=hello&page=2'
}

// テスト: ctx.cookie() クッキー取得
fn test_cookie_get() {
	mut app := hikari.new()
	app.get('/profile', fn (mut ctx hikari.Context) !hikari.Response {
		session := ctx.cookie('session')
		return ctx.text('session=${session}')
	})

	mut req := picohttpparser.Request{
		method:      'GET'
		path:        '/profile'
		num_headers: 1
	}
	req.headers[0] = picohttpparser.Header{
		name:  'Cookie'
		value: 'session=abc123; theme=dark'
	}
	mut ctx := hikari.Context{
		req:    req
		params: map[string]string{}
	}
	res := app.handle_request(mut ctx) or { panic(err) }
	assert res.status == 200
	assert res.body == 'session=abc123'
}

// テスト: ctx.cookies() 全クッキー取得
fn test_cookies_all() {
	mut app := hikari.new()
	app.get('/info', fn (mut ctx hikari.Context) !hikari.Response {
		all := ctx.cookies()
		return ctx.text('${all['session']}:${all['theme']}')
	})

	mut req := picohttpparser.Request{
		method:      'GET'
		path:        '/info'
		num_headers: 1
	}
	req.headers[0] = picohttpparser.Header{
		name:  'Cookie'
		value: 'session=xyz; theme=light'
	}
	mut ctx := hikari.Context{
		req:    req
		params: map[string]string{}
	}
	res := app.handle_request(mut ctx) or { panic(err) }
	assert res.status == 200
	assert res.body == 'xyz:light'
}

// テスト: ctx.set_cookie() レスポンスに Set-Cookie ヘッダーを設定
fn test_set_cookie() {
	mut app := hikari.new()
	app.get('/login', fn (mut ctx hikari.Context) !hikari.Response {
		ctx.set_cookie('session', 'tok123', hikari.CookieOptions{
			max_age:   3600
			http_only: true
			same_site: 'Lax'
		})
		return ctx.text('logged in')
	})

	mut ctx := hikari.Context{
		req:    picohttpparser.Request{
			method: 'GET'
			path:   '/login'
		}
		params: map[string]string{}
	}
	res := app.handle_request(mut ctx) or { panic(err) }
	assert res.status == 200
	assert res.set_cookies.len == 1
	assert res.set_cookies[0].contains('session=tok123')
	assert res.set_cookies[0].contains('Max-Age=3600')
	assert res.set_cookies[0].contains('HttpOnly')
	assert res.set_cookies[0].contains('SameSite=Lax')
}

// テスト: ctx.set_cookie() 複数クッキーの設定
fn test_set_multiple_cookies() {
	mut app := hikari.new()
	app.get('/setup', fn (mut ctx hikari.Context) !hikari.Response {
		ctx.set_cookie('session', 'abc', hikari.CookieOptions{})
		ctx.set_cookie('theme', 'dark', hikari.CookieOptions{
			http_only: false
		})
		return ctx.text('ok')
	})

	mut ctx := hikari.Context{
		req:    picohttpparser.Request{
			method: 'GET'
			path:   '/setup'
		}
		params: map[string]string{}
	}
	res := app.handle_request(mut ctx) or { panic(err) }
	assert res.status == 200
	assert res.set_cookies.len == 2
}

// テスト: body_limit ミドルウェア
fn test_body_limit_middleware() {
	mut app := hikari.new()
	app.use(hikari.body_limit(hikari.BodyLimitOptions{
		max_bytes: 10
	}))

	app.post('/data', fn (mut ctx hikari.Context) !hikari.Response {
		return ctx.text('received')
	})

	// ボディが小さい場合は通過する
	mut ctx_ok := hikari.Context{
		req:    picohttpparser.Request{
			method: 'POST'
			path:   '/data'
			body:   'hello'
		}
		params: map[string]string{}
	}
	res_ok := app.handle_request(mut ctx_ok) or { panic(err) }
	assert res_ok.status == 200

	// ボディが大きい場合は 413 を返す
	mut ctx_big := hikari.Context{
		req:    picohttpparser.Request{
			method: 'POST'
			path:   '/data'
			body:   'this body is too large'
		}
		params: map[string]string{}
	}
	res_big := app.handle_request(mut ctx_big) or { panic(err) }
	assert res_big.status == 413
}

// テスト: ヘッダーキャッシュ最適化 - 同じヘッダーを複数回取得
fn test_header_cache() {
	mut app := hikari.new()
	app.get('/auth', fn (mut ctx hikari.Context) !hikari.Response {
		// 同じヘッダーを複数回参照してもキャッシュが機能する
		auth1 := ctx.header('Authorization')
		auth2 := ctx.header('Authorization')
		auth3 := ctx.header('authorization') // 小文字でも取得できる
		assert auth1 == auth2
		assert auth1 == auth3
		return ctx.text('ok')
	})

	mut req := picohttpparser.Request{
		method:      'GET'
		path:        '/auth'
		num_headers: 1
	}
	req.headers[0] = picohttpparser.Header{
		name:  'Authorization'
		value: 'Bearer token123'
	}
	mut ctx := hikari.Context{
		req:    req
		params: map[string]string{}
	}
	res := app.handle_request(mut ctx) or { panic(err) }
	assert res.status == 200
}
