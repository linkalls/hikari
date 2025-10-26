module hikari

import time
import os
import encoding.base64

// Simple profiler middleware: records per-request elapsed time into a per-process
// CSV file under logs/. Enabled when HIKARI_PROFILE=1 (default 0).
pub fn profiler() Middleware {
	enabled := os.getenv_opt('HIKARI_PROFILE') or { '0' } == '1'
	return fn [enabled] (mut c Context, next Next) !Response {
		if !enabled {
			return next()!
		}
		start := time.now()
		res := next()!
		dur := time.now() - start
		// Record to per-process file to avoid cross-process locking issues
		if !os.is_dir('logs') {
			os.mkdir('logs') or {}
		}
		fname := 'logs/timings_${os.getpid()}.csv'
		// csv: timestamp, method, path, duration_ms
		mut f := os.open_file(fname, 'a') or { return res }
		s := '${time.now().format()},${c.request.method},${c.request.path},${dur.milliseconds()}'
		f.writeln(s) or {}
		f.close()
		return res
	}
}

// Hikari風の組み込みミドルウェア（超シンプル）
// --- async logger implementation (module-local) ---
struct LogEntry {
	file string
	msg  string
}

fn logger_background_worker(ch chan LogEntry) {
	// Keep a small cache of open file handles per filename.
	mut files := map[string]os.File{}
	for {
		entry := <-ch
		if entry.file == '' {
			// write to stdout (fast path)
			println(entry.msg)
			continue
		}

		// write to per-pid file (create if missing)
		if mut f := files[entry.file] {
			f.writeln(entry.msg) or {}
			continue
		}

		// try to open file and cache handle
		// create parent dir if needed
		if !os.is_dir('logs') {
			os.mkdir('logs') or {}
		}
		mut f := os.open_file(entry.file, 'a') or {
			// fallback to stdout
			println(entry.msg)
			continue
		}
		files[entry.file] = f
		f.writeln(entry.msg) or {}
	}
}

pub fn logger(opts ...map[string]bool) Middleware {
	// By default do not print per-request logs (stdout is slow under high concurrency).
	// Enable runtime logging with HIKARI_LOG=1 if you need human-readable logs.
	debug := os.getenv_opt('HIKARI_LOG') or { '' } == '1'

	// file logging option: if caller passes logger({'file': true}) then
	// middleware will append logs to logs/worker_<pid>.log instead of stdout.
	mut file_log := false
	if opts.len > 0 {
		// avoid implicit copy of the map by taking a reference
		opt_ref := &opts[0]
		if 'file' in *opt_ref {
			file_log = (*opt_ref)['file']
		}
	}

	// If file_log is requested, ensure logs dir exists.
	if file_log {
		if !os.is_dir('logs') {
			os.mkdir('logs') or {}
		}
	}

	// Create a per-middleware async logger (no globals). This is initialized
	// when the middleware is registered and captured by the returned closure.
	mut async_chan := chan LogEntry{}
	if debug {
		mut size := (os.getenv_opt('HIKARI_LOG_CHAN') or { '10000' }).int()
		if size <= 0 {
			size = 10000
		}
		unsafe {
			async_chan = chan LogEntry{cap: size}
		}
		go logger_background_worker(async_chan)
	}

	return fn [debug, file_log, async_chan] (mut c Context, next Next) !Response {
		if !debug {
			return next()!
		}

		start := time.now()
		res := next()!
		duration := time.now() - start
		msg := '[${time.now().format()}] ${c.request.method} ${c.request.path} - ${duration.milliseconds()}ms'

		entry := LogEntry{
			file: if file_log { 'logs/worker_${os.getpid()}.log' } else { '' }
			msg:  msg
		}

		// non-blocking send: drop when full
		select {
			async_chan <- entry {
				// enqueued successfully (no-op)
			}
			else {
				// drop log to avoid blocking
			}
		}

		return res
	}
}

pub fn cors(options ...string) Middleware {
	origins := if options.len > 0 { options[0] } else { '*' }

	return fn [origins] (mut c Context, next Next) !Response {
		if c.request.method == 'OPTIONS' {
			return Response{
				body:     ''.bytes()
				body_str: ''
				status:   204
				headers:  {
					'Access-Control-Allow-Origin':  origins
					'Access-Control-Allow-Methods': 'GET,POST,PUT,DELETE,OPTIONS'
					'Access-Control-Allow-Headers': 'Content-Type,Authorization'
				}
			}
		}
		mut res := next()!
		res.headers['Access-Control-Allow-Origin'] = origins
		return res
	}
}

// Hikari風のbasic auth
pub fn basic_auth(username string, password string) Middleware {
	return fn [username, password] (mut c Context, next Next) !Response {
		auth := c.header('Authorization')

		if !auth.starts_with('Basic ') {
			return Response{
				body:     'Unauthorized'.bytes()
				body_str: 'Unauthorized'
				status:   401
				headers:  {
					'WWW-Authenticate': 'Basic realm="Restricted"'
				}
			}
		}

		decoded_bytes := base64.decode(auth.replace('Basic ', ''))
		decoded := decoded_bytes.bytestr()

		parts := decoded.split(':')
		if parts.len != 2 || parts[0] != username || parts[1] != password {
			return Response{
				body:     'Unauthorized'.bytes()
				body_str: 'Unauthorized'
				status:   401
				headers:  {
					'WWW-Authenticate': 'Basic realm="Restricted"'
				}
			}
		}

		return next()!
	}
}
