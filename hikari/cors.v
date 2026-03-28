module hikari

pub struct CorsOptions {
pub:
	allow_origins []string = ['*']
	allow_methods []string = ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS']
	allow_headers []string = ['Origin', 'Content-Type', 'Accept', 'Authorization']
	expose_headers []string
	max_age       int = 86400
	credentials   bool
}

pub fn cors(options CorsOptions) Middleware {
	return fn [options] (mut ctx Context, next Next) !Response {
		origin := ctx.header('Origin')

		mut allowed_origin := ''
		if options.allow_origins.len > 0 {
			if '*' in options.allow_origins {
				allowed_origin = '*'
			} else if origin in options.allow_origins {
				allowed_origin = origin
			}
		}

		if ctx.req.method.to_upper() == 'OPTIONS' {
			mut res := Response{
				status: 204
				body: ''
				headers: ctx.headers.clone()
			}
			if allowed_origin != '' {
				res.headers['Access-Control-Allow-Origin'] = allowed_origin
			}
			if options.allow_methods.len > 0 {
				res.headers['Access-Control-Allow-Methods'] = options.allow_methods.join(', ')
			}
			if options.allow_headers.len > 0 {
				res.headers['Access-Control-Allow-Headers'] = options.allow_headers.join(', ')
			}
			if options.max_age > 0 {
				res.headers['Access-Control-Max-Age'] = options.max_age.str()
			}
			if options.credentials {
				res.headers['Access-Control-Allow-Credentials'] = 'true'
			}
			return res
		}

		mut res := next(mut ctx) or { return err }

		if allowed_origin != '' {
			res.headers['Access-Control-Allow-Origin'] = allowed_origin
		}
		if options.credentials {
			res.headers['Access-Control-Allow-Credentials'] = 'true'
		}
		if options.expose_headers.len > 0 {
			res.headers['Access-Control-Expose-Headers'] = options.expose_headers.join(', ')
		}

		return res
	}
}
