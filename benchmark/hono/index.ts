import { Hono } from 'hono'

const app = new Hono()

// JSON エンドポイント（フレームワーク比較の基準）
app.get('/', (c) => {
  return c.json({
    framework: 'Hono',
    language: 'TypeScript',
    speed: 'Blazing Fast'
  })
})

// プレーンテキストエンドポイント（最小オーバーヘッド計測）
app.get('/text', (c) => {
  return c.text('Hello, World!')
})

// パスパラメータエンドポイント（ルーター性能計測）
app.get('/users/:id', (c) => {
  const id = c.req.param('id')
  return c.json({ id, name: `User ${id}` })
})

export default {
  port: 3002,
  fetch: app.fetch,
}
