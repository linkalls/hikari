module hikari

import time
import encoding.base64

// Hikari風の組み込みミドルウェア（超シンプル）
pub fn logger() Middleware {
	return fn (c Context, next Next) !Response {
		start := time.now()

		res := next()!

		duration := time.now() - start
		println("[${time.now().format()}] ${c.req.method} ${c.req.path} - ${duration.milliseconds()}ms")

		return res
	}
}

pub fn cors(options ...string) Middleware {
	origins := if options.len > 0 { options[0] } else { "*" }

	return fn [origins] (c Context, next Next) !Response {
		if c.req.method == "OPTIONS" {
			return Response{
				body: ""
				status: 204
				headers: {
					"Access-Control-Allow-Origin": origins
					"Access-Control-Allow-Methods": "GET,POST,PUT,DELETE,OPTIONS"
					"Access-Control-Allow-Headers": "Content-Type,Authorization"
				}
			}
		}
		mut res := next()!
		res.headers["Access-Control-Allow-Origin"] = origins
		return res
	}
}

// Hikari風のbasic auth
pub fn basic_auth(username string, password string) Middleware {
	return fn [username, password] (c Context, next Next) !Response {
		auth := c.header("Authorization")

		if !auth.starts_with("Basic ") {
			return Response{
				body: "Unauthorized"
				status: 401
				headers: {"WWW-Authenticate": "Basic realm=\"Restricted\""}
			}
		}

		decoded_bytes := base64.decode(auth.replace("Basic ", ""))
		decoded := decoded_bytes.bytestr()

		parts := decoded.split(":")
		if parts.len != 2 || parts[0] != username || parts[1] != password {
			return Response{
				body: "Unauthorized"
				status: 401
				headers: {"WWW-Authenticate": "Basic realm=\"Restricted\""}
			}
		}

		return next()!
	}
}
