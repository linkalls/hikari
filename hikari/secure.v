module hikari

// セキュリティヘッダーの設定（Helmetに相当）
pub struct SecureOptions {
pub:
	// X-Content-Type-Options: nosniff を付与するか（デフォルト: true）
	x_content_type_options bool = true
	// X-Frame-Options の値（デフォルト: 'SAMEORIGIN'、空文字列で無効化）
	x_frame_options string = 'SAMEORIGIN'
	// X-XSS-Protection ヘッダーを付与するか（デフォルト: true）
	x_xss_protection bool = true
	// HSTS の max-age（秒単位、デフォルト: 31536000 = 1年、0で無効化）
	hsts_max_age int = 31536000
	// HSTS に includeSubDomains を含めるか（デフォルト: true）
	hsts_include_subdomains bool = true
	// Content-Security-Policy の値（空文字列で無効化）
	content_security_policy string = "default-src 'self'"
	// Referrer-Policy の値（空文字列で無効化）
	referrer_policy string = 'no-referrer'
	// X-Download-Options: noopen を付与するか（デフォルト: true）
	x_download_options bool = true
	// X-Permitted-Cross-Domain-Policies の値（空文字列で無効化）
	x_permitted_cross_domain_policies string = 'none'
}

// セキュリティヘッダーミドルウェア（Helmet風）
// レスポンスに主要なセキュリティヘッダーを自動付与する
pub fn secure(options SecureOptions) Middleware {
	return fn [options] (mut ctx Context, next Next) !Response {
		mut res := next(mut ctx) or { return err }

		if options.x_content_type_options {
			res.headers['X-Content-Type-Options'] = 'nosniff'
		}
		if options.x_frame_options != '' {
			res.headers['X-Frame-Options'] = options.x_frame_options
		}
		if options.x_xss_protection {
			res.headers['X-XSS-Protection'] = '1; mode=block'
		}
		if options.hsts_max_age > 0 {
			mut hsts := 'max-age=${options.hsts_max_age}'
			if options.hsts_include_subdomains {
				hsts += '; includeSubDomains'
			}
			res.headers['Strict-Transport-Security'] = hsts
		}
		if options.content_security_policy != '' {
			res.headers['Content-Security-Policy'] = options.content_security_policy
		}
		if options.referrer_policy != '' {
			res.headers['Referrer-Policy'] = options.referrer_policy
		}
		if options.x_download_options {
			res.headers['X-Download-Options'] = 'noopen'
		}
		if options.x_permitted_cross_domain_policies != '' {
			res.headers['X-Permitted-Cross-Domain-Policies'] = options.x_permitted_cross_domain_policies
		}

		return res
	}
}
