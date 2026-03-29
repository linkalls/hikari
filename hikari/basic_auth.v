module hikari

import encoding.base64

// Basic 認証の設定
pub struct BasicAuthOptions {
pub:
	// 認証するユーザー名
	username string
	// 認証するパスワード
	password string
	// 認証ダイアログに表示されるレルム（デフォルト: 'Restricted Area'）
	realm string = 'Restricted Area'
}

// Basic 認証ミドルウェア
// Authorization: Basic <credentials> ヘッダーを検証し、
// 認証に失敗した場合は 401 Unauthorized を返す
pub fn basic_auth(options BasicAuthOptions) Middleware {
	return fn [options] (mut ctx Context, next Next) !Response {
		auth := ctx.header('Authorization')
		if auth.starts_with('Basic ') {
			credentials := base64.decode_str(auth[6..])
			if credentials == '${options.username}:${options.password}' {
				return next(mut ctx)
			}
		}

		mut res := Response{
			status:  401
			body:    'Unauthorized'
			headers: ctx.headers.clone()
		}
		res.headers['WWW-Authenticate'] = 'Basic realm="${options.realm}"'
		res.headers['Content-Type'] = 'text/plain; charset=utf-8'
		return res
	}
}
