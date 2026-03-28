module hikari

import time

pub fn logger() Middleware {
	return fn (mut ctx Context, next Next) !Response {
		start_time := time.now()
		method := ctx.req.method
		path := ctx.req.path

		mut res := next(mut ctx) or {
			elapsed := f64(time.since(start_time).microseconds()) / 1000.0
			println('[Hikari] ${method} ${path} - ERROR - ${elapsed}ms')
			return err
		}

		elapsed := f64(time.since(start_time).microseconds()) / 1000.0
		println('[Hikari] ${method} ${path} - ${res.status} - ${elapsed}ms')

		return res
	}
}
