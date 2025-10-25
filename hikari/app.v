module hikari

import veb
import regex
import os
// NOTE: we rely on Linux PR_SET_PDEATHSIG in the child for automatic
// child termination when the parent dies. Parent-side signal handlers
// can be added later for macOS/Windows if needed.

$if !windows {
	// POSIX interop
	#include <signal.h>

	fn C.signal(int, voidptr) voidptr
	fn C.kill(int, int) int
	fn C._exit(int)
	fn C.getpgrp() int
	fn C.setpgid(int, int) int
	fn C.killpg(int, int) int
	fn C.atexit(voidptr) int
}

$if windows {
	// Windows: we'll shell out to taskkill when needed
	#include <stdlib.h>

	fn C.atexit(voidptr) int
	fn C.exit(int)
}

$if linux {
	#include <sys/prctl.h>
	#include <signal.h>

	fn C.prctl(int, int, int, int, int) int
}

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
	// 3 try /proc/cpuinfo first (avoids spawning a shell)
	if os.is_readable('/proc/cpuinfo') {
		txt := os.read_file('/proc/cpuinfo') or { return 1 }
		cnt := txt.split('\n').filter(it.starts_with('processor')).len
		if cnt > 0 {
			return cnt
		}
	}
	// 4 fallback: try nproc if available
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

// POSIX signal handler: kill our whole process group on SIGINT/SIGTERM.
// This avoids any module-level globals; children inherit the master's
// process group and will receive the signal from the kernel.
fn sig_handler(sig int) {
	// On signal, perform our best-effort cleanup using the same routine
	// used by Windows atexit fallback: read logs/children.pids and kill
	// recorded child PIDs. Then exit.
	exit_handler()
	$if !windows {
		C._exit(0)
	} $else {
		C.exit(0)
	}
}

// V-friendly wrapper for os.signal handlers. Converts os.Signal to int
fn sig_handler_wrapper(s os.Signal) {
	sig_handler(int(s))
}

// atexit handler used on Windows as a best-effort fallback: taskkill children
fn exit_handler() {
	// Read recorded child PIDs and try to terminate them.
	if !os.is_readable('logs/children.pids') {
		return
	}
	content := os.read_file('logs/children.pids') or { return }
	lines := content.split('\n')
	for l in lines {
		s := l.trim_space()
		if s == '' {
			continue
		}
		pid := s.int()
		if pid <= 0 {
			continue
		}
		$if windows {
			_ := os.execute('taskkill /PID ${pid} /T /F')
		} $else {
			C.kill(pid, 15)
		}
	}
	// try to remove the file after cleanup
	os.rm('logs/children.pids') or {}
}

// Hikari()コンストラクタ
pub fn new() &Hikari {
	// Allow overriding pool parameters via env for experimentation without
	// changing source. Environment variables:
	//   HIKARI_POOL_BUF  (default 1024)
	//   HIKARI_POOL_COUNT (default 2048)
	mut buf_size := 1024
	mut buf_count := 2048
	if v := os.getenv_opt('HIKARI_POOL_BUF') {
		if v != '' {
			buf_size = v.int()
		}
	}
	if v := os.getenv_opt('HIKARI_POOL_COUNT') {
		if v != '' {
			buf_count = v.int()
		}
	}

	return &Hikari{
		routes:           map[string][]Route{}
		path_middlewares: map[string][]Middleware{}
		exact_routes:     map[string]map[string]Route{}
		tries:            map[string]&TrieNode{}
		pool:             new_pool(buf_size, buf_count)
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
	// Behaviour: spawn child processes directly (not via shell/nohup) so that
	// they are real child processes of this master. In addition, child
	// processes set PR_SET_PDEATHSIG (Linux) so the kernel will send them a
	// SIGTERM if the parent dies — this makes sure children don't become orphans
	// when the master is killed.
	if workers > 1 && !is_child {
		exe := os.executable()
		// ensure logs dir exists for worker output (kept for compatibility)
		if !os.is_dir('logs') {
			os.mkdir('logs') or {}
		}

		// Do NOT change the master's process group here. Changing it may cause
		// the terminal to stop delivering SIGINT (Ctrl+C) to this process.
		// Instead we rely on recorded child PIDs (logs/children.pids) and
		// the atexit/signal handlers to terminate children explicitly.

		// record spawned pids in module-global so signal handler can access
		mut spawned_pids := []int{}

		for i in 1 .. workers {
			port_i := server_port + i
			// Allow optionally redirecting child stdio to /dev/null to avoid any
			// stdio contention under high load. Set HIKARI_CHILD_STDIO=devnull to
			// enable this behavior. Default is to use os.new_process (inherit
			// parent's stdio) which avoids shells and extra overhead.
			mut child_pid := 0
			if (os.getenv_opt('HIKARI_CHILD_STDIO') or { '' }) == 'devnull' {
				// Start the child detached with stdout/stderr redirected to /dev/null.
				// Use nohup via the shell; os.execute already runs via /bin/sh -c so
				// quoting exe with " is sufficient to handle spaces in the path.
				cmd := 'nohup "' + exe +
					'" --port ${port_i} --hikari-child > /dev/null 2>&1 & echo $!'
				res := os.execute(cmd)
				if res.exit_code == 0 {
					out := res.output.trim_space()
					if out != '' {
						child_pid = out.int()
					}
				} else {
					eprintln('Hikari: failed to spawn worker (devnull mode) for port ${port_i}: ${res.output}')
				}
			} else {
				mut p := os.new_process(exe)
				// pass CLI args to child
				p.set_args(['--port', '${port_i}', '--hikari-child'])
				// start the child process without redirecting stdio to avoid pipe
				// overhead under high load. Child output will inherit the parent's
				// stdout/stderr (we disable noisy logs in examples during perf tests).
				p.run()
				// If run failed, p.err may contain useful info; log it for debugging.
				if p.status == .running && p.pid > 0 {
					child_pid = p.pid
				} else {
					eprintln('Hikari: failed to spawn worker for port ${port_i}: ${p.err}')
				}
			}
			// check for runtime error recorded on Process struct
			if child_pid == 0 {
				eprintln('Hikari: failed to spawn worker for port ${port_i}')
				continue
			}
			spawned_pids << child_pid
			// Always append child PID to logs/children.pids so exit/atexit
			// handlers can read and cleanup without relying on globals.
			if !os.is_dir('logs') {
				os.mkdir('logs') or {}
			}
			mut f := os.open_file('logs/children.pids', 'a') or { continue }
			f.writeln('${child_pid}') or {}
			f.close()
		}

		println('Hikari master: started ${workers} workers (pids=${spawned_pids}); parent will run in foreground on port ${server_port}')
		// Continue on to run the current process as the foreground worker.
	}

	// Register parent-side handlers for graceful cleanup of spawned children.
	if !is_child {
		$if !windows {
			// Use V's os.signal_opt to reliably register handlers in the
			// runtime (works better than binding C.signal directly).
			_ := os.signal_opt(.int, sig_handler_wrapper) or { unsafe { nil } }
			_ := os.signal_opt(.term, sig_handler_wrapper) or { unsafe { nil } }
		} $else {
			// Best-effort on Windows: register an atexit handler so that normal
			// exits (or ctrl-close) attempt to kill spawned children via taskkill.
			C.atexit(voidptr(exit_handler))
		}
	}

	// Child or single-worker path: start internal veb app
	mut internal := &InternalVebApp{
		hikari_app: app
	}
	app.internal_app = internal

	// If this process was invoked as a child, set PR_SET_PDEATHSIG so the kernel
	// sends us SIGTERM when our parent dies. This makes worker termination
	// deterministic if the master process is killed. Only applied on Linux.
	if is_child {
		$if linux {
			// PR_SET_PDEATHSIG == 1, SIGTERM == 15 on POSIX — call prctl
			// Note: we don't fail if prctl is unavailable; it's a best-effort safety.
			C.prctl(1, 15, 0, 0, 0)
		}
	}

	// Only print a startup message from the master; avoid noisy worker logs.
	// Gate master startup message behind HIKARI_LOG so benchmarks can run
	// without extra stdout contention.
	if !is_child {
		if (os.getenv_opt('HIKARI_LOG') or { '' }) == '1' {
			println('🔥 Hikari master: running on port ${server_port}')
		}
	}

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
	// normalize method to uppercase for consistent map keys
	m := method.to_upper()

	// If the route has no parameters, store it in exact_routes for O(1) lookup.
	if route.pattern.param_names.len == 0 {
		if m !in app.exact_routes {
			app.exact_routes[m] = map[string]Route{}
		}
		app.exact_routes[m][path] = route
		return
	}

	// Parameterized route: insert into per-method trie for fast lookup.
	// Initialize trie root if needed.
	if m !in app.tries {
		app.tries[m] = new_trienode()
	}

	// Insert path segments into trie. Example: /users/:id/posts -> ["users",":id","posts"]
	// get or create trie root for this method
	mut node := app.tries[m] or { new_trienode() }
	if m !in app.tries {
		app.tries[m] = node
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
		method: veb_ctx.req.method.str().to_upper()
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
	method := ctx.request.method.to_upper()

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
