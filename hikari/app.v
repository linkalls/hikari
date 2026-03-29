module hikari

import picoev
import picohttpparser

@[heap]
pub struct Hikari {
pub mut:
	routes        map[string]&TrieNode
	middlewares   []Middleware
	error_handler ?ErrorHandler
}

// ルートグループ: プレフィックスと共通ミドルウェアを持つルートのグループ
@[heap]
pub struct RouteGroup {
mut:
	app         &Hikari
	prefix      string
	middlewares []Middleware
}

pub fn (mut g RouteGroup) use(middleware Middleware) {
	g.middlewares << middleware
}

pub fn (mut g RouteGroup) get(path string, handler Handler, middlewares ...Middleware) {
	mut all_mws := g.middlewares.clone()
	all_mws << middlewares
	g.app.add_route('GET', g.prefix + path, handler, ...all_mws)
}

pub fn (mut g RouteGroup) post(path string, handler Handler, middlewares ...Middleware) {
	mut all_mws := g.middlewares.clone()
	all_mws << middlewares
	g.app.add_route('POST', g.prefix + path, handler, ...all_mws)
}

pub fn (mut g RouteGroup) put(path string, handler Handler, middlewares ...Middleware) {
	mut all_mws := g.middlewares.clone()
	all_mws << middlewares
	g.app.add_route('PUT', g.prefix + path, handler, ...all_mws)
}

pub fn (mut g RouteGroup) delete(path string, handler Handler, middlewares ...Middleware) {
	mut all_mws := g.middlewares.clone()
	all_mws << middlewares
	g.app.add_route('DELETE', g.prefix + path, handler, ...all_mws)
}

pub fn (mut g RouteGroup) patch(path string, handler Handler, middlewares ...Middleware) {
	mut all_mws := g.middlewares.clone()
	all_mws << middlewares
	g.app.add_route('PATCH', g.prefix + path, handler, ...all_mws)
}

pub fn new() &Hikari {
	return &Hikari{
		routes:        map[string]&TrieNode{}
		middlewares:   []Middleware{}
		error_handler: none
	}
}

pub fn (mut app Hikari) use(middleware Middleware) {
	app.middlewares << middleware
}

pub fn (mut app Hikari) set_error_handler(handler ErrorHandler) {
	app.error_handler = handler
}

// Middleware execution chain
@[heap]
struct MiddlewareChain {
mut:
	middlewares []Middleware
	handler     Handler = unsafe { nil }
	index       int
}

fn (mut chain MiddlewareChain) next(mut ctx Context) !Response {
	if chain.index < chain.middlewares.len {
		mw := chain.middlewares[chain.index]
		chain.index++
		return mw(mut ctx, fn [mut chain] (mut c Context) !Response {
			return chain.next(mut c)
		})
	}
	return chain.handler(mut ctx)
}

fn (mut app Hikari) add_route(method string, path string, handler Handler, middlewares ...Middleware) {
	m := method.to_upper()
	if m !in app.routes {
		app.routes[m] = new_trienode()
	}
	mut root := app.routes[m] or { new_trienode() }
	app.routes[m] = root
	root.add_route(path, handler, middlewares)
}

pub fn (mut app Hikari) get(path string, handler Handler, middlewares ...Middleware) {
	app.add_route('GET', path, handler, ...middlewares)
}

pub fn (mut app Hikari) post(path string, handler Handler, middlewares ...Middleware) {
	app.add_route('POST', path, handler, ...middlewares)
}

pub fn (mut app Hikari) put(path string, handler Handler, middlewares ...Middleware) {
	app.add_route('PUT', path, handler, ...middlewares)
}

pub fn (mut app Hikari) delete(path string, handler Handler, middlewares ...Middleware) {
	app.add_route('DELETE', path, handler, ...middlewares)
}

pub fn (mut app Hikari) patch(path string, handler Handler, middlewares ...Middleware) {
	app.add_route('PATCH', path, handler, ...middlewares)
}

pub fn (mut app Hikari) head(path string, handler Handler, middlewares ...Middleware) {
	app.add_route('HEAD', path, handler, ...middlewares)
}

pub fn (mut app Hikari) options(path string, handler Handler, middlewares ...Middleware) {
	app.add_route('OPTIONS', path, handler, ...middlewares)
}

pub fn (mut app Hikari) static(path string, root_dir string) {
	// e.g. path = "/public", root_dir = "./public"
	// We need to match /public, /public/, and /public/*
	handler := static_handler(path, root_dir)
	mut route_path := path
	if route_path.ends_with('/') {
		route_path = route_path[0..route_path.len - 1]
	}

	app.get(route_path, handler)
	app.get(route_path + '/', handler)
	app.get(route_path + '/:path...', handler)
}

// ルートグループを作成する
// グループに登録したルートは全てプレフィックスが付与される
pub fn (mut app Hikari) group(prefix string, middlewares ...Middleware) &RouteGroup {
	return &RouteGroup{
		app:         unsafe { app }
		prefix:      prefix
		middlewares: middlewares
	}
}

// Request processing pipeline.
// Can be called directly for testing.
pub fn (mut app Hikari) handle_request(mut ctx Context) !Response {
	// 標準的な HTTP メソッドは既に大文字なのでアロケーションを回避する
	method := match ctx.req.method {
		'GET', 'POST', 'PUT', 'DELETE', 'PATCH', 'HEAD', 'OPTIONS', 'CONNECT', 'TRACE' {
			ctx.req.method
		}
		else {
			ctx.req.method.to_upper()
		}
	}
	mut path := ctx.req.path
	q_idx := path.index_u8(`?`)
	if q_idx >= 0 {
		path = path[..q_idx]
	}

	// HEAD メソッド: 専用ルートがなければ GET ルートにフォールバック
	lookup_method := if method == 'HEAD' && 'HEAD' !in app.routes { 'GET' } else { method }

	// Route mapping
	if lookup_method in app.routes {
		mut root := app.routes[lookup_method] or { return ctx.not_found() }
		if node, route_mws := root.find_route(path, mut ctx) {
			if handler := node.handler {
				// グローバルミドルウェアとルートミドルウェアをマージ
				// 不要なクローンを避けて速度を最適化する
				all_mws := if app.middlewares.len == 0 {
					route_mws
				} else if route_mws.len == 0 {
					app.middlewares
				} else {
					mut mws := app.middlewares.clone()
					mws << route_mws
					mws
				}

				mut chain := &MiddlewareChain{
					middlewares: all_mws
					handler:     handler
					index:       0
				}

				resp := chain.next(mut ctx) or {
					if err_handler := app.error_handler {
						return err_handler(err, mut ctx)
					}
					// HttpError のステータスコードを自動的に使用する
					// IError.code() が 400-599 の場合は HTTP ステータスコードとして扱う
					err_code := err.code()
					if err_code >= 100 && err_code <= 599 {
						mut err_headers := if ctx.headers.len > 0 {
							ctx.headers.clone()
						} else {
							map[string]string{}
						}
						err_headers['Content-Type'] = 'text/plain; charset=utf-8'
						return Response{
							status:  err_code
							body:    err.msg()
							headers: err_headers
						}
					}
					return err
				}
				// HEAD メソッドはボディを返さない
				if method == 'HEAD' {
					mut head_resp := resp
					head_resp.body = ''
					return head_resp
				}
				return resp
			}
		}
	} else if method == 'OPTIONS' {
		// Run global middlewares for OPTIONS if no specific route is found, primarily for CORS
		// Fallback handler for OPTIONS
		handler := fn (mut ctx Context) !Response {
			return ctx.text('Method Not Allowed')
		}

		mut chain := &MiddlewareChain{
			middlewares: app.middlewares
			handler:     handler
			index:       0
		}

		resp := chain.next(mut ctx) or {
			if err_handler := app.error_handler {
				return err_handler(err, mut ctx)
			}
			return err
		}
		return resp
	}
	return ctx.not_found()
}

// 任意のHTTPステータスコードに対応するステータスラインを書き込む
fn write_status_line(mut res picohttpparser.Response, status int) {
	match status {
		200 { res.write_string('HTTP/1.1 200 OK\r\n') }
		201 { res.write_string('HTTP/1.1 201 Created\r\n') }
		202 { res.write_string('HTTP/1.1 202 Accepted\r\n') }
		204 { res.write_string('HTTP/1.1 204 No Content\r\n') }
		206 { res.write_string('HTTP/1.1 206 Partial Content\r\n') }
		301 { res.write_string('HTTP/1.1 301 Moved Permanently\r\n') }
		302 { res.write_string('HTTP/1.1 302 Found\r\n') }
		303 { res.write_string('HTTP/1.1 303 See Other\r\n') }
		304 { res.write_string('HTTP/1.1 304 Not Modified\r\n') }
		307 { res.write_string('HTTP/1.1 307 Temporary Redirect\r\n') }
		308 { res.write_string('HTTP/1.1 308 Permanent Redirect\r\n') }
		400 { res.write_string('HTTP/1.1 400 Bad Request\r\n') }
		401 { res.write_string('HTTP/1.1 401 Unauthorized\r\n') }
		403 { res.write_string('HTTP/1.1 403 Forbidden\r\n') }
		404 { res.write_string('HTTP/1.1 404 Not Found\r\n') }
		405 { res.write_string('HTTP/1.1 405 Method Not Allowed\r\n') }
		408 { res.write_string('HTTP/1.1 408 Request Timeout\r\n') }
		409 { res.write_string('HTTP/1.1 409 Conflict\r\n') }
		410 { res.write_string('HTTP/1.1 410 Gone\r\n') }
		413 { res.write_string('HTTP/1.1 413 Payload Too Large\r\n') }
		415 { res.write_string('HTTP/1.1 415 Unsupported Media Type\r\n') }
		422 { res.write_string('HTTP/1.1 422 Unprocessable Entity\r\n') }
		429 { res.write_string('HTTP/1.1 429 Too Many Requests\r\n') }
		500 { res.write_string('HTTP/1.1 500 Internal Server Error\r\n') }
		501 { res.write_string('HTTP/1.1 501 Not Implemented\r\n') }
		502 { res.write_string('HTTP/1.1 502 Bad Gateway\r\n') }
		503 { res.write_string('HTTP/1.1 503 Service Unavailable\r\n') }
		504 { res.write_string('HTTP/1.1 504 Gateway Timeout\r\n') }
		else { res.write_string('HTTP/1.1 200 OK\r\n') }
	}
}

// picoev callback execution
fn pico_cb(void_ptr_app voidptr, req picohttpparser.Request, mut res picohttpparser.Response) {
	unsafe {
		mut app := &Hikari(void_ptr_app)
		mut ctx := Context{
			req:     req
			res:     res
			params:  map[string]string{}
			query:   map[string]string{}
			headers: map[string]string{}
		}
		ctx.parse_query()

		if resp := app.handle_request(mut ctx) {
			write_status_line(mut res, resp.status)
			for k, v in resp.headers {
				res.header(k, v)
			}
			// Set-Cookie ヘッダーを複数書き出す
			for cookie in resp.set_cookies {
				res.header('Set-Cookie', cookie)
			}
			// Content-Length を自動付与（HTTP/1.1 の keep-alive に必要）
			res.header('Content-Length', resp.body.len.str())
			res.body(resp.body)
			_ = res.end()
		} else {
			res.http_500()
			res.body('Internal Server Error')
			_ = res.end()
		}
	}
}

pub fn (mut app Hikari) fire(port int) {
	println('🔥 Hikari starting on port ${port}')
	mut p := picoev.new(
		port:      port
		host:      '0.0.0.0'
		family:    .ip
		cb:        pico_cb
		user_data: app
	) or { panic(err) }
	p.serve()
}
