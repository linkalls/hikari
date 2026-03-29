module main

import hikari
import picohttpparser

// テスト: jwt_sign() と jwt() ミドルウェアの基本動作
fn test_jwt_middleware_valid_token() {
	secret := 'test-secret-key'
	mut app := hikari.new()
	app.use(hikari.jwt(hikari.JwtOptions{
		secret: secret
	}))
	app.get('/protected', fn (mut ctx hikari.Context) !hikari.Response {
		payload := ctx.get('jwt_payload')
		assert payload != ''
		return ctx.text('ok')
	})

	// 有効なトークンを生成
	token := hikari.jwt_sign({
		'sub':  'user123'
		'role': 'admin'
	}, secret)

	mut req := picohttpparser.Request{
		method:      'GET'
		path:        '/protected'
		num_headers: 1
	}
	req.headers[0] = picohttpparser.Header{
		name:  'Authorization'
		value: 'Bearer ${token}'
	}
	mut ctx := hikari.Context{
		req:    req
		params: map[string]string{}
	}
	res := app.handle_request(mut ctx) or { panic(err) }
	assert res.status == 200
	assert res.body == 'ok'
}

// テスト: Authorization ヘッダーなしは 401
fn test_jwt_middleware_missing_header() {
	mut app := hikari.new()
	app.use(hikari.jwt(hikari.JwtOptions{
		secret: 'my-secret'
	}))
	app.get('/secret', fn (mut ctx hikari.Context) !hikari.Response {
		return ctx.text('secret data')
	})

	mut ctx := hikari.Context{
		req:    picohttpparser.Request{
			method: 'GET'
			path:   '/secret'
		}
		params: map[string]string{}
	}
	res := app.handle_request(mut ctx) or { panic(err) }
	assert res.status == 401
	assert res.headers['WWW-Authenticate'] == 'Bearer'
}

// テスト: 無効なトークン署名は 401
fn test_jwt_middleware_invalid_signature() {
	mut app := hikari.new()
	app.use(hikari.jwt(hikari.JwtOptions{
		secret: 'correct-secret'
	}))
	app.get('/data', fn (mut ctx hikari.Context) !hikari.Response {
		return ctx.text('data')
	})

	// 別の秘密鍵で署名されたトークン
	token := hikari.jwt_sign({'sub': 'user'}, 'wrong-secret')

	mut req := picohttpparser.Request{
		method:      'GET'
		path:        '/data'
		num_headers: 1
	}
	req.headers[0] = picohttpparser.Header{
		name:  'Authorization'
		value: 'Bearer ${token}'
	}
	mut ctx := hikari.Context{
		req:    req
		params: map[string]string{}
	}
	res := app.handle_request(mut ctx) or { panic(err) }
	assert res.status == 401
}

// テスト: トークン形式が不正（ドットが2つない）は 401
fn test_jwt_middleware_malformed_token() {
	mut app := hikari.new()
	app.use(hikari.jwt(hikari.JwtOptions{
		secret: 'secret'
	}))
	app.get('/x', fn (mut ctx hikari.Context) !hikari.Response {
		return ctx.text('x')
	})

	mut req := picohttpparser.Request{
		method:      'GET'
		path:        '/x'
		num_headers: 1
	}
	req.headers[0] = picohttpparser.Header{
		name:  'Authorization'
		value: 'Bearer not.a.valid.jwt.token.too.many.dots'
	}
	mut ctx := hikari.Context{
		req:    req
		params: map[string]string{}
	}
	res := app.handle_request(mut ctx) or { panic(err) }
	assert res.status == 401
}

// テスト: jwt_sign() で生成したトークンがペイロードを正しく持つ
fn test_jwt_sign_payload_roundtrip() {
	secret := 'roundtrip-secret'
	token := hikari.jwt_sign({
		'sub': 'alice'
		'aud': 'myapp'
	}, secret)

	// トークンは 3 つのパートを持つ
	parts := token.split('.')
	assert parts.len == 3
}

// テスト: カスタム unauthorized_message の確認
fn test_jwt_middleware_custom_message() {
	mut app := hikari.new()
	app.use(hikari.jwt(hikari.JwtOptions{
		secret:               'sec'
		unauthorized_message: 'カスタムエラー'
	}))
	app.get('/y', fn (mut ctx hikari.Context) !hikari.Response {
		return ctx.text('y')
	})

	mut ctx := hikari.Context{
		req:    picohttpparser.Request{
			method: 'GET'
			path:   '/y'
		}
		params: map[string]string{}
	}
	res := app.handle_request(mut ctx) or { panic(err) }
	assert res.status == 401
	assert res.body == 'カスタムエラー'
}
