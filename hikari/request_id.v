module hikari

import rand

// リクエストIDミドルウェア
// 各リクエストに一意の X-Request-ID ヘッダーを付与する
// リクエストに既に X-Request-ID が含まれている場合はそれを使用する
pub fn request_id() Middleware {
	return fn (mut ctx Context, next Next) !Response {
		id := ctx.header('X-Request-ID')
		request_id_val := if id != '' { id } else { rand.uuid_v4() }

		// コンテキストストアに保存してハンドラから参照できるようにする
		ctx.set('request_id', request_id_val)

		mut res := next(mut ctx) or { return err }
		res.headers['X-Request-ID'] = request_id_val
		return res
	}
}
