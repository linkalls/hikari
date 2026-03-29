module hikari

import crypto.md5
import encoding.hex

// ETag ミドルウェア
// レスポンスボディの MD5 ハッシュを ETag ヘッダーとして付与する
// クライアントが If-None-Match ヘッダーを送信している場合、
// ETag が一致すれば 304 Not Modified を返す（帯域幅の節約）
pub fn etag() Middleware {
	return fn (mut ctx Context, next Next) !Response {
		mut res := next(mut ctx) or { return err }

		// ETag は 200 OK のレスポンスにのみ付与する
		if res.status != 200 || res.body == '' {
			return res
		}

		hash := md5.sum(res.body.bytes())
		etag_val := '"${hex.encode(hash)}"'

		// If-None-Match ヘッダーが一致する場合は 304 を返す
		if_none_match := ctx.header('If-None-Match')
		if if_none_match == etag_val {
			return Response{
				status:  304
				body:    ''
				headers: res.headers.clone()
			}
		}

		res.headers['ETag'] = etag_val
		return res
	}
}
