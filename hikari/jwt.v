module hikari

import crypto.hmac
import crypto.sha256
import encoding.base64
import json

// JWT ミドルウェアの設定
pub struct JwtOptions {
pub:
	// JWT の署名に使用する秘密鍵
	secret string
	// 認証スキーム（デフォルト: 'Bearer'）
	scheme string = 'Bearer'
	// 署名検証失敗時のカスタムメッセージ
	unauthorized_message string = 'Unauthorized'
}

// JWT クレームを表す構造体（標準クレームのサブセット）
pub struct JwtClaims {
pub:
	sub string // Subject（ユーザー識別子）
	iss string // Issuer（発行者）
	exp i64    // Expiration（有効期限、UNIX タイムスタンプ）
	iat i64    // Issued At（発行日時、UNIX タイムスタンプ）
	jti string // JWT ID（一意識別子）
}

// base64url エンコード（RFC 4648 §5、パディングなし）
fn base64url_encode(data []u8) string {
	return base64.encode(data).replace('+', '-').replace('/', '_').trim_right('=')
}

// base64url デコード（RFC 4648 §5、パディングなし）
fn base64url_decode(s string) ![]u8 {
	mut padded := s.replace('-', '+').replace('_', '/')
	rem := padded.len % 4
	if rem == 1 {
		return error('invalid base64url length')
	} else if rem == 2 {
		padded += '=='
	} else if rem == 3 {
		padded += '='
	}
	return base64.decode(padded)
}

// HMAC-SHA256 を使用して JWT トークンを生成する
// payload には任意のキー/バリュー（文字列）を指定できる
pub fn jwt_sign(payload map[string]string, secret string) string {
	header_b64 := base64url_encode('{"alg":"HS256","typ":"JWT"}'.bytes())
	payload_json := json.encode(payload)
	payload_b64 := base64url_encode(payload_json.bytes())
	signing_input := '${header_b64}.${payload_b64}'
	sig := hmac.new(secret.bytes(), signing_input.bytes(), sha256.sum, sha256.block_size)
	return '${signing_input}.${base64url_encode(sig)}'
}

// JWT HS256 認証ミドルウェア
// Authorization: Bearer <token> ヘッダーを検証する
// 検証成功時はペイロード JSON を ctx.store['jwt_payload'] に保存する
pub fn jwt(options JwtOptions) Middleware {
	return fn [options] (mut ctx Context, next Next) !Response {
		auth := ctx.header('Authorization')
		prefix := options.scheme + ' '
		if !auth.starts_with(prefix) {
			return unauthorized_response(mut ctx, options.unauthorized_message)
		}

		token := auth[prefix.len..]
		parts := token.split('.')
		if parts.len != 3 {
			return unauthorized_response(mut ctx, options.unauthorized_message)
		}

		// 署名を再計算して検証
		signing_input := '${parts[0]}.${parts[1]}'
		expected_sig := hmac.new(options.secret.bytes(), signing_input.bytes(), sha256.sum,
			sha256.block_size)
		expected_b64 := base64url_encode(expected_sig)
		if parts[2] != expected_b64 {
			return unauthorized_response(mut ctx, options.unauthorized_message)
		}

		// ペイロードをデコードしてコンテキストストアに保存
		payload_bytes := base64url_decode(parts[1]) or {
			return unauthorized_response(mut ctx, options.unauthorized_message)
		}
		ctx.set('jwt_payload', payload_bytes.bytestr())

		return next(mut ctx)
	}
}

// 401 Unauthorized レスポンスを生成するヘルパー
fn unauthorized_response(mut ctx Context, message string) !Response {
	mut res := Response{
		status:  401
		body:    message
		headers: if ctx.headers.len > 0 { ctx.headers.clone() } else { map[string]string{} }
	}
	res.headers['Content-Type'] = 'text/plain; charset=utf-8'
	res.headers['WWW-Authenticate'] = 'Bearer'
	return res
}
