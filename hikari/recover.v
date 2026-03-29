module hikari

pub fn recover() Middleware {
	return fn (mut ctx Context, next Next) !Response {
		// V's panic handling is not fully capable of catching all panics within closures
		// safely without using specific compiler flags or C-level setjmp/longjmp,
		// but we can at least catch errors returned gracefully.
		// For a true panic recovery, we would need to wrap the handler in a safe execution context.
		// For now, we will handle `!Response` errors and convert unexpected errors to 500.

		mut res := next(mut ctx) or {
			println('[Hikari] Panic recovered: ${err}')
			mut error_res := Response{
				status: 500
				body: 'Internal Server Error'
				headers: ctx.headers.clone()
			}
			error_res.headers['Content-Type'] = 'text/plain; charset=utf-8'
			return error_res
		}

		return res
	}
}
