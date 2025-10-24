module hikari
import veb
import regex

// Placeholder for Pattern struct
struct Pattern {
    raw_path string
    regex    regex.RE
}

type PathOrMiddleware = string | Middleware

struct Route {
	pattern Pattern
	middlewares []Middleware
	handler Handler = unsafe { nil }
}

// 内部veb委譲アプリ（完全隠蔽）
pub struct InternalVebApp {
mut:
	hikari_app &Hikari
}

// veb.Contextをhikari.Contextに変換する内部型
type HikariContext = Context

// Hikariそっくりなメインアプリ
pub struct Hikari {
mut:
	routes map[string][]Route
	middlewares []Middleware
	path_middlewares map[string][]Middleware
	internal_app &InternalVebApp = unsafe { nil }
}

// Hikari()コンストラクタ（完全にHikariと同じ）
pub fn new() &Hikari {
	return &Hikari{
		routes: map[string][]Route{}
		path_middlewares: map[string][]Middleware{}
	}
}

// Hikariライクなルート定義
pub fn (mut app Hikari) get(path string, handler Handler, middlewares ...Middleware) &Hikari {
	app.add_route("GET", path, handler, middlewares)
	return app
}

pub fn (mut app Hikari) post(path string, handler Handler, middlewares ...Middleware) &Hikari {
	app.add_route("POST", path, handler, middlewares)
	return app
}

pub fn (mut app Hikari) put(path string, handler Handler, middlewares ...Middleware) &Hikari {
	app.add_route("PUT", path, handler, middlewares)
	return app
}

pub fn (mut app Hikari) delete(path string, handler Handler, middlewares ...Middleware) &Hikari {
	app.add_route("DELETE", path, handler, middlewares)
	return app
}

pub fn (mut app Hikari) all(path string, handler Handler, middlewares ...Middleware) &Hikari {
	methods := ["GET", "POST", "PUT", "DELETE", "PATCH", "HEAD", "OPTIONS"]
	for method in methods {
		app.add_route(method, path, handler, middlewares)
	}
	return app
}

// Hikariライクなミドルウェア
pub fn (mut app Hikari) use(path_or_middleware PathOrMiddleware, middleware ...Middleware) &Hikari {
	if path_or_middleware is string {
		// パス付きミドルウェア app.use("/api/*", middleware)
		path := path_or_middleware
		for m in middleware {
			app.add_middleware_with_path(path, m)
		}
	} else if path_or_middleware is Middleware {
		// グローバルミドルウェア app.use(middleware)
		app.middlewares << path_or_middleware
	}
	return app
}

// Hikari風のルートグループ
pub fn (mut app Hikari) route(path string, sub_app &Hikari) &Hikari {
	// サブアプリのルートを現在のアプリにマージ
	for method, routes in sub_app.routes {
		for route in routes {
			new_pattern := compile_pattern(path + route.pattern.raw_path)
			new_route := Route{
				pattern: new_pattern
				middlewares: route.middlewares
				handler: route.handler
			}

			if method !in app.routes {
				app.routes[method] = []Route{}
			}
			app.routes[method] << new_route
		}
	}
	return app
}

// Hikari風のサーバ起動（serve関数）
pub fn (mut app Hikari) fire(port ...int) ! {
	server_port := if port.len > 0 { port[0] } else { 3000 }

	// 内部vebアプリを作成（完全隠蔽）
	mut internal := &InternalVebApp{
		hikari_app: app
	}
	app.internal_app = internal

	println("🔥 Hikari server is running on port ${server_port}")

	// vebで起動（内部実装）
	veb.run[InternalVebApp, HikariContext](mut internal, server_port)
}

// 内部実装
fn (mut app Hikari) add_route(method string, path string, handler Handler, middlewares []Middleware) {
	if method !in app.routes {
		app.routes[method] = []Route{}
	}

	route := Route{
		pattern: compile_pattern(path)
		middlewares: middlewares
		handler: handler
	}

	app.routes[method] << route
}

// Placeholder for add_middleware_with_path
fn (mut app Hikari) add_middleware_with_path(path string, m Middleware) {
    if path !in app.path_middlewares {
        app.path_middlewares[path] = []Middleware{}
    }
    app.path_middlewares[path] << m
}

@["/:path..."]
fn (mut internal InternalVebApp) handle_all(mut veb_ctx veb.Context, path string) veb.Result {
	// veb.ContextをHikariライクなContextに変換
	mut hikari_ctx := create_hikari_context(veb_ctx, path)

	// Hikariアプリでリクエスト処理
	response := internal.hikari_app.handle_request(mut hikari_ctx) or {
		return veb_ctx.text("Internal Server Error")
	}

	// Hikariレスポンスをveb.Resultに変換
	for key, value in response.headers {
		veb_ctx.set_custom_header(key, value) or {}
	}
	veb_ctx.res.status_code = response.status
	return veb_ctx.text(response.body)
}

@["/"]
fn (mut internal InternalVebApp) index(mut veb_ctx veb.Context) veb.Result {
	return internal.handle_all(mut veb_ctx, "/")
}

// 内部変換関数（完全隠蔽）
fn create_hikari_context(veb_ctx veb.Context, path string) Context {
	request_path := if path == "" { "/" } else {
		if path.starts_with("/") { path } else { "/${path}" }
	}

	mut headers := map[string]string{}
	for key in veb_ctx.req.header.keys() {
		headers[key] = veb_ctx.req.header.get_custom(key) or { "" }
	}

	req := Request{
		method: veb_ctx.req.method.str()
		url: veb_ctx.req.url
		path: request_path
		query: veb_ctx.query
		header: headers
		body: veb_ctx.req.data
	}

	return Context{
		Context: veb_ctx,
		req: req,
		var: map[string]Any{},
	}
}

// Placeholder for compile_pattern function
fn compile_pattern(path string) Pattern {
    return Pattern{
        raw_path: path,
        regex: regex.new('') or { panic(err) }
    }
}

// Placeholder for handle_request method
pub fn (app &Hikari) handle_request(mut ctx Context) !Response {
    for route in app.routes[ctx.req.method] {
        if ctx.req.path == route.pattern.raw_path {
            return route.handler(ctx)
        }
    }
    return ctx.not_found()
}
