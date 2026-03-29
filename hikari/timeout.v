module hikari

import time

// タイムアウトミドルウェアの設定
pub struct TimeoutOptions {
pub:
	// タイムアウト時間（ミリ秒単位、デフォルト: 30,000ms = 30秒）
	timeout_ms i64 = 30_000
	// タイムアウト時のカスタムメッセージ
	message string = 'Request Timeout'
}

// タイムアウトミドルウェア
// 指定された時間を超えて処理が完了しない場合に 408 Request Timeout を返す
// 注意: V言語の現在のシングルスレッドモデルでは真の並行タイムアウトは
// 実現できないため、ハンドラ完了後に経過時間をチェックする
pub fn timeout(options TimeoutOptions) Middleware {
	return fn [options] (mut ctx Context, next Next) !Response {
		start := time.now()
		mut res := next(mut ctx) or { return err }
		elapsed_ms := time.since(start).milliseconds()
		if elapsed_ms > options.timeout_ms {
			mut timeout_res := Response{
				status:      408
				body:        options.message
				headers:     if ctx.headers.len > 0 { ctx.headers.clone() } else { map[string]string{} }
				set_cookies: ctx.set_cookies.clone()
			}
			timeout_res.headers['Content-Type'] = 'text/plain; charset=utf-8'
			return timeout_res
		}
		return res
	}
}
