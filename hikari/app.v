module hikari

import picoev
import picohttpparser

@[heap]
pub struct Hikari {
pub mut:
	routes      map[string]&TrieNode
	middlewares []Middleware
}

pub fn new() &Hikari {
	return &Hikari{
		routes:      map[string]&TrieNode{}
		middlewares: []Middleware{}
	}
}

pub fn (mut app Hikari) use(middleware Middleware) {
	app.middlewares << middleware
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

// Request processing pipeline.
// Can be called directly for testing.
pub fn (mut app Hikari) handle_request(mut ctx Context) !Response {
	method := ctx.req.method.to_upper()
	mut path := ctx.req.path
	if path.contains('?') {
		path = path.split('?')[0]
	}

	// Route mapping
	if method in app.routes {
		mut root := app.routes[method] or { return ctx.not_found() }
		if node, _ := root.find_route(path, mut ctx) {
			if handler := node.handler {
				return handler(mut ctx)
			}
		}
	}
	return ctx.not_found()
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
			match resp.status {
				200 { res.http_ok() }
				404 { res.http_404() }
				405 { res.http_405() }
				500 { res.http_500() }
				else { res.http_ok() } // Fallback
			}
			for k, v in resp.headers {
				res.header(k, v)
			}
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
