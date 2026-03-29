module main

import hikari
import picohttpparser

// テスト: レートリミットミドルウェア
fn test_rate_limit_middleware() {
	mut app := hikari.new()
	app.use(hikari.rate_limit(hikari.RateLimitOptions{
		max:       2
		window_ms: 60000
	}))

	app.get('/api', fn (mut ctx hikari.Context) !hikari.Response {
		return ctx.text('OK')
	})

	// 2回までは通過できる
	for _ in 0 .. 2 {
		mut ctx := hikari.Context{
			req:    picohttpparser.Request{
				method: 'GET'
				path:   '/api'
			}
			params: map[string]string{}
		}
		res := app.handle_request(mut ctx) or { panic(err) }
		assert res.status == 200
		assert res.headers['X-RateLimit-Limit'] == '2'
	}

	// 3回目は 429 になる
	mut ctx := hikari.Context{
		req:    picohttpparser.Request{
			method: 'GET'
			path:   '/api'
		}
		params: map[string]string{}
	}
	res := app.handle_request(mut ctx) or { panic(err) }
	assert res.status == 429
	assert res.headers['X-RateLimit-Remaining'] == '0'
}

// テスト: Request ID ミドルウェア
fn test_request_id_middleware() {
	mut app := hikari.new()
	app.use(hikari.request_id())

	app.get('/', fn (mut ctx hikari.Context) !hikari.Response {
		return ctx.text('Hello')
	})

	// 既存の X-Request-ID を使用するケース
	mut req := picohttpparser.Request{
		method:      'GET'
		path:        '/'
		num_headers: 1
	}
	req.headers[0] = picohttpparser.Header{
		name:  'X-Request-ID'
		value: 'existing-id-123'
	}
	mut ctx := hikari.Context{
		req:    req
		params: map[string]string{}
	}
	res := app.handle_request(mut ctx) or { panic(err) }
	assert res.status == 200
	assert res.headers['X-Request-ID'] == 'existing-id-123'

	// X-Request-ID がない場合は自動生成
	mut ctx2 := hikari.Context{
		req:    picohttpparser.Request{
			method: 'GET'
			path:   '/'
		}
		params: map[string]string{}
	}
	res2 := app.handle_request(mut ctx2) or { panic(err) }
	assert res2.status == 200
	assert res2.headers['X-Request-ID'] != ''
}

// テスト: セキュリティヘッダーミドルウェア
fn test_secure_middleware() {
	mut app := hikari.new()
	app.use(hikari.secure(hikari.SecureOptions{}))

	app.get('/', fn (mut ctx hikari.Context) !hikari.Response {
		return ctx.text('OK')
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
	assert res.headers['X-Content-Type-Options'] == 'nosniff'
	assert res.headers['X-Frame-Options'] == 'SAMEORIGIN'
	assert res.headers['X-XSS-Protection'] == '1; mode=block'
	assert res.headers['Referrer-Policy'] == 'no-referrer'
}

// テスト: ETag ミドルウェア
fn test_etag_middleware() {
	mut app := hikari.new()
	app.use(hikari.etag())

	app.get('/data', fn (mut ctx hikari.Context) !hikari.Response {
		return ctx.text('Hello World')
	})

	// 初回リクエスト: ETag ヘッダーが付与される
	mut ctx := hikari.Context{
		req:    picohttpparser.Request{
			method: 'GET'
			path:   '/data'
		}
		params: map[string]string{}
	}
	res := app.handle_request(mut ctx) or { panic(err) }
	assert res.status == 200
	etag_val := res.headers['ETag']
	assert etag_val != ''
	assert etag_val.starts_with('"')
	assert etag_val.ends_with('"')

	// If-None-Match 付きリクエスト: 304 が返る
	mut req2 := picohttpparser.Request{
		method:      'GET'
		path:        '/data'
		num_headers: 1
	}
	req2.headers[0] = picohttpparser.Header{
		name:  'If-None-Match'
		value: etag_val
	}
	mut ctx2 := hikari.Context{
		req:    req2
		params: map[string]string{}
	}
	res2 := app.handle_request(mut ctx2) or { panic(err) }
	assert res2.status == 304
	assert res2.body == ''
}

// テスト: Basic 認証ミドルウェア
fn test_basic_auth_middleware() {
	mut app := hikari.new()
	app.use(hikari.basic_auth(hikari.BasicAuthOptions{
		username: 'admin'
		password: 'secret'
		realm:    'Test Area'
	}))

	app.get('/admin', fn (mut ctx hikari.Context) !hikari.Response {
		return ctx.text('Welcome Admin')
	})

	// 認証なし: 401 になる
	mut ctx_no_auth := hikari.Context{
		req:    picohttpparser.Request{
			method: 'GET'
			path:   '/admin'
		}
		params: map[string]string{}
	}
	res_no_auth := app.handle_request(mut ctx_no_auth) or { panic(err) }
	assert res_no_auth.status == 401
	assert res_no_auth.headers['WWW-Authenticate'].contains('Basic realm=')

	// 正しい認証情報: admin:secret -> YWRtaW46c2VjcmV0
	mut req_ok := picohttpparser.Request{
		method:      'GET'
		path:        '/admin'
		num_headers: 1
	}
	req_ok.headers[0] = picohttpparser.Header{
		name:  'Authorization'
		value: 'Basic YWRtaW46c2VjcmV0'
	}
	mut ctx_ok := hikari.Context{
		req:    req_ok
		params: map[string]string{}
	}
	res_ok := app.handle_request(mut ctx_ok) or { panic(err) }
	assert res_ok.status == 200
	assert res_ok.body == 'Welcome Admin'

	// 間違った認証情報: 401 になる
	mut req_bad := picohttpparser.Request{
		method:      'GET'
		path:        '/admin'
		num_headers: 1
	}
	req_bad.headers[0] = picohttpparser.Header{
		name:  'Authorization'
		value: 'Basic d3Jvbmc6Y3JlZHM='
	}
	mut ctx_bad := hikari.Context{
		req:    req_bad
		params: map[string]string{}
	}
	res_bad := app.handle_request(mut ctx_bad) or { panic(err) }
	assert res_bad.status == 401
}
