module hikari

import veb
import regex
import os

// helper: detect workers and cli flags
fn detect_workers() int {
	// 1 explicit env
	mut w := ''
	w = os.getenv_opt('HIKARI_WORKERS') or { '' }
	if w != '' {
		val := w.int()
		if val > 0 {
			return val
		}
	}
	// 2 HIKARI_MODE=dev -> 1
	if (os.getenv_opt('HIKARI_MODE') or { '' }) == 'dev' {
		return 1
	}
	// 3 try nproc
	res := os.execute('nproc --all')
	if res.exit_code == 0 {
		out := res.output.trim_space()
		if out != '' {
			val := out.int()
			if val > 0 {
				return val
			}
		}
	}
	// 4 try /proc/cpuinfo
	if os.is_readable('/proc/cpuinfo') {
		txt := os.read_file('/proc/cpuinfo') or { return 1 }
		cnt := txt.split('\n').filter(it.starts_with('processor')).len
		if cnt > 0 {
			return cnt
		}
	}
	return 1
}

// Placeholder for Pattern struct
struct Pattern {
	raw_path string
mut:
	regex       regex.RE
	param_names []string
}

type PathOrMiddleware = string | Middleware

struct Route {
mut:
	pattern     Pattern
	middlewares []Middleware
	handler     ?Handler
}

// Simple trie node for path segments. Supports static children and a single
// parameter child per node (e.g. ":id"). This keeps implementation small
// while providing large speedups vs regex for common parameterized routes.
pub struct TrieNode {
pub mut:
	// static segment -> child
	children map[string]&TrieNode
	// param_name is used when this node represents a parameter segment (stored under key ":")
	param_name string
	// handler + middlewares at this node (leaf)
	handler     ?Handler
	middlewares []Middleware
}

fn new_trienode() &TrieNode {
	return &TrieNode{
		children:   map[string]&TrieNode{}
		param_name: ''
	}
}

pub struct InternalVebApp {
mut:
	hikari_app Hikari
}

// veb.Contextをhikari.Contextに変換する内部型
type HikariContext = Context

pub struct Hikari {
mut:
	routes           map[string][]Route
	middlewares      []Middleware
	path_middlewares map[string][]Middleware
	// exact_routes[method][path] -> Route for fast O(1) lookup of static paths
	exact_routes map[string]map[string]Route
	// tries[method] -> root of trie for parameterized routes
	tries map[string]&TrieNode
	// buffer pool for response reuse
	pool         &BufferPool
	internal_app ?&InternalVebApp
}

// Hikari()コンストラクタ
pub fn new() &Hikari {
	return &Hikari{
		routes:           map[string][]Route{}
		path_middlewares: map[string][]Middleware{}
		exact_routes:     map[string]map[string]Route{}
		tries:            map[string]&TrieNode{}
		pool:             new_pool(512, 1024)
	}
}

pub fn (mut app Hikari) get(path string, handler Handler, middlewares ...Middleware) &Hikari {
	app.add_route('GET', path, handler, middlewares)
	return app
}

pub fn (mut app Hikari) post(path string, handler Handler, middlewares ...Middleware) &Hikari {
	app.add_route('POST', path, handler, middlewares)
	return app
}

pub fn (mut app Hikari) put(path string, handler Handler, middlewares ...Middleware) &Hikari {
	app.add_route('PUT', path, handler, middlewares)
	return app
}

pub fn (mut app Hikari) delete(path string, handler Handler, middlewares ...Middleware) &Hikari {
	app.add_route('DELETE', path, handler, middlewares)
	return app
}

pub fn (mut app Hikari) all(path string, handler Handler, middlewares ...Middleware) &Hikari {
	methods := ['GET', 'POST', 'PUT', 'DELETE', 'PATCH', 'HEAD', 'OPTIONS']
	for method in methods {
		app.add_route(method, path, handler, middlewares)
	}
	return app
}

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
	// Merge parameterized routes
	for method, routes in sub_app.routes {
		for route in routes {
			new_pattern := compile_pattern(path + route.pattern.raw_path)
			new_route := Route{
				pattern:     new_pattern
				middlewares: route.middlewares
				handler:     route.handler
			}

			if new_route.pattern.param_names.len == 0 {
				if method !in app.exact_routes {
					app.exact_routes[method] = map[string]Route{}
				}
				app.exact_routes[method][new_route.pattern.raw_path] = new_route
			} else {
				if method !in app.routes {
					app.routes[method] = []Route{}
				}
				app.routes[method] << new_route
			}
		}
	}

	// Merge exact routes from sub_app
	for method, exacts in sub_app.exact_routes {
		for p, r in exacts {
			new_pattern := compile_pattern(path + r.pattern.raw_path)
			new_route := Route{
				pattern:     new_pattern
				middlewares: r.middlewares
				handler:     r.handler
			}
			if method !in app.exact_routes {
				app.exact_routes[method] = map[string]Route{}
			}
			app.exact_routes[method][p] = new_route
		}
	}
	return app
}

// Hikari風のサーバ起動（serve関数）
pub fn (mut app Hikari) fire(port ...int) ! {
	// determine server port: explicit arg > --port CLI > PORT env > 3000
	mut server_port := if port.len > 0 { port[0] } else { 0 }
	if server_port == 0 {
		// search CLI args for --port
		args := os.args
		for i := 0; i < args.len; i++ {
			if args[i] == '--port' && i + 1 < args.len {
				server_port = args[i + 1].int()
			}
		}
	}
	if server_port == 0 {
		mut p := ''
		p = os.getenv_opt('PORT') or { '' }
		if p != '' {
			server_port = p.int()
		}
	}
	if server_port == 0 {
		server_port = 3000
	}

	// decide number of workers (framework-level)
	mut workers := 1
	// if caller passed explicit --hikari-child flag, treat this as child
	is_child := (os.getenv_opt('HIKARI_CHILD') or { '' }) == '1' || '--hikari-child' in os.args
	if !is_child {
		// not a child: detect desired worker count
		workers = detect_workers()
	}

	// If multiple workers requested and this is the master process, spawn children.
	// Behaviour: spawn background workers for ports (server_port+1 ..) and keep
	// the current process running in the foreground on `server_port`. This
	// prevents the shell from immediately returning (server backgrounded) and
	// avoids flooding the terminal with each child's stdout. Child stdout/stderr
	// are redirected to `logs/worker_<port>.log`.
	if workers > 1 && !is_child {
		exe := os.executable()
		// ensure logs dir exists for worker output
		if !os.is_dir('logs') {
			os.mkdir('logs') or {}
		}

		// Spawn background workers for ports server_port+1 .. server_port+(workers-1)
		// Keep the parent process as the foreground worker on `server_port`.
		for i in 1 .. workers {
			port_i := server_port + i
			// use nohup + shell backgrounding so the child detaches from terminal
			// and its output goes to a per-worker logfile.
			cmd := 'nohup ${exe} --port ${port_i} --hikari-child > logs/worker_${port_i}.log 2>&1 &'
			// run via sh -c to interpret the & backgrounding
			_ := os.execute('sh -c "${cmd}"')
		}

		// Print a single summary line instead of per-worker spawn logs.
		println('Hikari master: started ${workers} workers; parent will run in foreground on port ${server_port}')
		// Continue on to run the current process as the foreground worker.
	}

	// Child or single-worker path: start internal veb app
	mut internal := &InternalVebApp{
		hikari_app: app
	}
	app.internal_app = internal

	println('🔥 Hikari server is running on port ${server_port} (worker)')

	// vebで起動（内部実装）
	veb.run[InternalVebApp, HikariContext](mut internal, server_port)
}

// 内部実装
fn (mut app Hikari) add_route(method string, path string, handler Handler, middlewares []Middleware) {
	route := Route{
		pattern:     compile_pattern(path)
		middlewares: middlewares
		handler:     handler
	}

	// If the route has no parameters, store it in exact_routes for O(1) lookup.
	if route.pattern.param_names.len == 0 {
		if method !in app.exact_routes {
			app.exact_routes[method] = map[string]Route{}
		}
		app.exact_routes[method][path] = route
		return
	}

	// Parameterized route: insert into per-method trie for fast lookup.
	// Initialize trie root if needed.
	if method !in app.tries {
		app.tries[method] = new_trienode()
	}

	// Insert path segments into trie. Example: /users/:id/posts -> ["users",":id","posts"]
	// get or create trie root for this method
	mut node := app.tries[method] or { new_trienode() }
	if method !in app.tries {
		app.tries[method] = node
	}

	// trim leading '/'
	mut trimmed := path
	if trimmed.len > 0 && trimmed[0] == `/` {
		trimmed = trimmed[1..]
	}
	segs := if trimmed == '' { []string{} } else { trimmed.split('/') }

	if segs.len == 0 {
		// root path
		node.handler = handler
		node.middlewares = middlewares
		return
	}

	for seg in segs {
		if seg.len == 0 {
			continue
		}
		if seg[0] == `:` {
			// parameter child stored under special key ':'
			if ':' !in node.children {
				mut child := new_trienode()
				child.param_name = if seg.len > 1 { seg[1..] } else { '' }
				node.children[':'] = child
			}
			node = node.children[':'] or { new_trienode() }
		} else {
			if seg !in node.children {
				node.children[seg] = new_trienode()
			}
			node = node.children[seg] or { new_trienode() }
		}
	}
	node.handler = handler
	node.middlewares = middlewares
	node.handler = handler
	node.middlewares = middlewares
}

// Placeholder for add_middleware_with_path
fn (mut app Hikari) add_middleware_with_path(path string, m Middleware) {
	if path !in app.path_middlewares {
		app.path_middlewares[path] = []Middleware{}
	}
	app.path_middlewares[path] << m
}

@['/:path...']
fn (mut internal InternalVebApp) handle_all(mut veb_ctx veb.Context, path string) veb.Result {
	mut hikari_ctx := create_hikari_context(veb_ctx, path)
	mut response := Response{}

	// Hikariアプリでリクエスト処理
	response = internal.hikari_app.handle_request(mut hikari_ctx) or {
		return veb_ctx.text('Internal Server Error')
	}

	// Hikariレスポンスをveb.Resultに変換
	for key, value in response.headers {
		veb_ctx.set_custom_header(key, value) or {}
	}
	veb_ctx.res.status_code = response.status
	// Prefer cached body_str to avoid bytes->string conversion at send time.
	if response.body_str != '' {
		// recycle buffer back to pool
		if response.body.len > 0 {
			mut p := internal.hikari_app.pool
			p.give(mut response.body)
		}
		return veb_ctx.text(response.body_str)
	}

	// convert bytes to string for veb and then recycle buffer
	s := response.body.bytestr()
	if response.body.len > 0 {
		mut p := internal.hikari_app.pool
		p.give(mut response.body)
	}
	return veb_ctx.text(s)
}

@['/']
fn (mut internal InternalVebApp) index(mut veb_ctx veb.Context) veb.Result {
	return internal.handle_all(mut veb_ctx, '/')
}

// 内部変換関数（完全隠蔽）
fn create_hikari_context(veb_ctx veb.Context, path string) Context {
	request_path := if path == '' {
		'/'
	} else {
		if path.starts_with('/') { path } else { '/${path}' }
	}

	// Avoid copying all headers into a new map per-request —
	// instead keep an empty map and let Context.header() query the
	// embedded veb.Context on demand. This reduces per-request
	// allocations which can help with GC/latency spikes under load.
	req := Request{
		method: veb_ctx.req.method.str()
		url:    veb_ctx.req.url
		path:   request_path
		query:  veb_ctx.query
		header: map[string]string{}
		body:   veb_ctx.req.data
	}

	return Context{
		Context: veb_ctx
		request: req
		var:     map[string]Any{}
	}
}

// Placeholder for compile_pattern function
fn compile_pattern(path string) Pattern {
	mut param_names := []string{}
	mut regex_path := path
	mut re := regex.regex_opt(r':(\w+)') or { panic(err) }
	matches := re.find_all_str(path)
	for m in matches {
		param_name := m.replace(':', '')
		param_names << param_name
		regex_path = regex_path.replace(m, r'(\w+)')
	}
	return Pattern{
		raw_path:    path
		regex:       regex.regex_opt(regex_path + '$') or { panic(err) }
		param_names: param_names
	}
}

// Placeholder for handle_request method
pub fn (mut app Hikari) handle_request(mut ctx Context) !Response {
	method := ctx.request.method

	// 1) Exact-match fast path using exact_routes map
	if method in app.exact_routes {
		if m := app.exact_routes[method] {
			if route := m[ctx.request.path] { // zero-value check: Route is a struct
				if handler := route.handler {
					return handler(mut ctx)
				}
			}
		}
	}

	// 2) Fallback: match against trie for parameterized routes
	if method in app.tries {
		mut node := app.tries[method] or { new_trienode() }
		if method !in app.tries {
			app.tries[method] = node
		}

		// trim leading '/'
		mut trimmed := ctx.request.path
		if trimmed.len > 0 && trimmed[0] == `/` {
			trimmed = trimmed[1..]
		}
		segs := if trimmed == '' { []string{} } else { trimmed.split('/') }

		if segs.len == 0 {
			// root
			if node.handler != none {
				return node.handler(mut ctx)
			}
		} else {
			mut matched := true
			for seg in segs {
				if seg.len == 0 {
					continue
				}
				if seg in node.children {
					node = node.children[seg] or { new_trienode() }
					continue
				}
				if ':' in node.children {
					// parameter child
					mut child := node.children[':'] or { new_trienode() }
					ctx.params[child.param_name] = seg
					node = child
					continue
				}
				matched = false
				break
			}
			if matched && node.handler != none {
				return node.handler(mut ctx)
			}
		}
	}

	return ctx.not_found()
}
