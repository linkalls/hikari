module hikari

import time
import os
import encoding.base64

// Hikari風の組み込みミドルウェア（超シンプル）
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

	return fn [debug, file_log] (mut c Context, next Next) !Response {
		if !debug {
			return next()!
		}

		start := time.now()
		res := next()!
		duration := time.now() - start
		msg := '[${time.now().format()}] ${c.request.method} ${c.request.path} - ${duration.milliseconds()}ms'

		if file_log {
			// append to per-process logfile
			fname := 'logs/worker_${os.getpid()}.log'
			mut f := os.open_file(fname, 'a') or {
				// fallback to console if file open fails
				println(msg)
				return res
			}
			f.writeln(msg) or {}
			f.close()
		} else {
			println(msg)
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
