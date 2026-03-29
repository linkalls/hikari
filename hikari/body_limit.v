module hikari

// BodyLimit ミドルウェアの設定
pub struct BodyLimitOptions {
pub:
	// 許可する最大ボディサイズ（バイト単位、デフォルト: 1MB）
	max_bytes int = 1_048_576
	// リミット超過時のカスタムメッセージ
	message string = 'Request Entity Too Large'
}

// ボディサイズ制限ミドルウェア
// リクエストボディが指定サイズを超えた場合、413 Payload Too Large を返す
pub fn body_limit(options BodyLimitOptions) Middleware {
	return fn [options] (mut ctx Context, next Next) !Response {
		if ctx.req.body.len > options.max_bytes {
			mut res := Response{
				status:      413
				body:        options.message
				headers:     ctx.headers.clone()
				set_cookies: ctx.set_cookies.clone()
			}
			res.headers['Content-Type'] = 'text/plain; charset=utf-8'
			return res
		}
		return next(mut ctx)
	}
}
