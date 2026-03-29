module hikari

import compress.gzip

// Gzip 圧縮ミドルウェア
// クライアントが Accept-Encoding: gzip を送信している場合、
// レスポンスボディを gzip 圧縮して返す
// 圧縮によりスループットが向上し、帯域幅を削減できる
pub fn compress() Middleware {
	return fn (mut ctx Context, next Next) !Response {
		mut res := next(mut ctx) or { return err }

		// 空のボディや小さすぎるボディは圧縮しない（オーバーヘッドが大きい）
		if res.body.len < 512 {
			return res
		}

		// クライアントが gzip を受け付けるか確認
		accept_encoding := ctx.header('Accept-Encoding')
		if !accept_encoding.contains('gzip') {
			return res
		}

		// 既に圧縮済みの場合はスキップ
		if _ := res.headers['Content-Encoding'] {
			return res
		}

		compressed := gzip.compress(res.body.bytes()) or {
			// 圧縮に失敗した場合は元のレスポンスをそのまま返す
			return res
		}

		res.body = compressed.bytestr()
		res.headers['Content-Encoding'] = 'gzip'
		res.headers['Vary'] = 'Accept-Encoding'
		return res
	}
}
