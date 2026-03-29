module main

import hikari

fn main() {
	mut app := hikari.new()

	// JSON エンドポイント（フレームワーク比較の基準）
	app.get('/', fn (mut c hikari.Context) !hikari.Response {
		return c.json({
			'framework': 'Hikari'
			'language':  'V'
			'speed':     'Blazing Fast'
		})
	})

	// プレーンテキストエンドポイント（最小オーバーヘッド計測）
	app.get('/text', fn (mut c hikari.Context) !hikari.Response {
		return c.text('Hello, World!')
	})

	// パスパラメータエンドポイント（ルーター性能計測）
	app.get('/users/:id', fn (mut c hikari.Context) !hikari.Response {
		id := c.param('id')
		return c.json({
			'id':   id
			'name': 'User ${id}'
		})
	})

	app.fire(3000)
}
