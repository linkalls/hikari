module hikari

import time
import sync

// レートリミットの設定
pub struct RateLimitOptions {
pub:
	// ウィンドウ内の最大リクエスト数（デフォルト: 100）
	max int = 100
	// ウィンドウの長さ（ミリ秒単位、デフォルト: 60,000ms = 1分）
	window_ms i64 = 60000
	// レート制限キーを決定する関数（デフォルト: X-Forwarded-For または空文字列）
	key_fn ?fn (mut Context) string
	// リミット超過時のカスタムメッセージ
	message string = 'Too Many Requests'
}

struct RateLimitEntry {
mut:
	count    int
	reset_at i64
}

// レートリミットミドルウェア
// 指定されたウィンドウ内でリクエスト数を制限する
pub fn rate_limit(options RateLimitOptions) Middleware {
	mut store := map[string]RateLimitEntry{}
	mut mu := sync.new_mutex()
	return fn [options, mut store, mut mu] (mut ctx Context, next Next) !Response {
		key := if kf := options.key_fn {
			kf(mut ctx)
		} else {
			ctx.header('X-Forwarded-For')
		}

		now := time.now().unix_milli()

		mu.@lock()
		mut entry := store[key] or {
			RateLimitEntry{
				count:    0
				reset_at: now + options.window_ms
			}
		}
		if now > entry.reset_at {
			entry = RateLimitEntry{
				count:    0
				reset_at: now + options.window_ms
			}
		}
		entry.count++
		store[key] = entry
		count := entry.count
		reset_at := entry.reset_at
		mu.unlock()

		remaining := if count <= options.max { options.max - count } else { 0 }

		if count > options.max {
			mut res := Response{
				status:  429
				body:    options.message
				headers: ctx.headers.clone()
			}
			res.headers['Content-Type'] = 'text/plain; charset=utf-8'
			res.headers['X-RateLimit-Limit'] = options.max.str()
			res.headers['X-RateLimit-Remaining'] = '0'
			res.headers['X-RateLimit-Reset'] = (reset_at / 1000).str()
			res.headers['Retry-After'] = ((reset_at - now) / 1000).str()
			return res
		}

		mut res := next(mut ctx) or { return err }
		res.headers['X-RateLimit-Limit'] = options.max.str()
		res.headers['X-RateLimit-Remaining'] = remaining.str()
		res.headers['X-RateLimit-Reset'] = (reset_at / 1000).str()
		return res
	}
}
