# 速度最適化と新機能 (Performance & New Features)

## 速度最適化 (Performance Improvements)

### ヘッダーキャッシュ (Header Cache)

`ctx.header()` は初回アクセス時にリクエストヘッダーを小文字化した内部キャッシュを構築します。
同じリクエスト内で複数回 `ctx.header()` を呼び出しても、O(1) でアクセスできます。

```v
// 複数のミドルウェアが同じヘッダーを参照しても効率的
auth := ctx.header('Authorization')      // キャッシュ構築
accept := ctx.header('Accept')           // キャッシュ参照（O(1)）
content_type := ctx.header('content-type') // 大文字小文字を区別しない
```

### クエリ解析最適化 (Query Parsing Optimization)

`parse_query()` はメモリ割り当てを最小化するため、`string.split('?')` の代わりに
`index_u8` によるオフセット計算でクエリ文字列を抽出します。

### Content-Length ヘッダーの自動付与

HTTP/1.1 の keep-alive を正しく機能させるため、全レスポンスに自動的に
`Content-Length` ヘッダーが付与されます。これによりクライアントがボディを
先読みでき、コネクションの再利用効率が向上します。

---

## 新機能 (New Features)

### クエリパラメータ便利メソッド

```v
app.get('/search', fn (mut c hikari.Context) !hikari.Response {
    q    := c.query_value('q')    // ?q=hello → "hello"
    page := c.query_value('page') // ?page=2  → "2"
    // 存在しない場合は空文字列を返す
    missing := c.query_value('missing') // → ""
    return c.text('q=${q}, page=${page}')
})
```

### Cookie サポート

```v
// Cookie の読み取り
app.get('/me', fn (mut c hikari.Context) !hikari.Response {
    session := c.cookie('session')  // 単一クッキーを取得
    all := c.cookies()              // 全クッキーを map で取得
    return c.text('session=${session}')
})

// Cookie の書き込み
app.post('/login', fn (mut c hikari.Context) !hikari.Response {
    c.set_cookie('session', 'tok123', hikari.CookieOptions{
        max_age:   3600
        http_only: true
        same_site: 'Strict'
    })
    c.set_cookie('theme', 'dark', hikari.CookieOptions{
        http_only: false
        max_age:   86400 * 365
    })
    return c.redirect('/dashboard', 302)
})
```

### ボディサイズ制限ミドルウェア (body_limit)

リクエストボディのサイズを制限し、大きすぎるリクエストを `413 Payload Too Large` で拒否します。

```v
// アプリ全体に 1MB の制限を設ける（デフォルト）
app.use(hikari.body_limit(hikari.BodyLimitOptions{}))

// API エンドポイントには 100KB まで許可する
app.use(hikari.body_limit(hikari.BodyLimitOptions{
    max_bytes: 102_400
    message:   'ボディが大きすぎます'
}))
```

#### BodyLimitOptions

| フィールド | 型 | デフォルト | 説明 |
|---|---|---|---|
| `max_bytes` | `int` | `1_048_576` | 許可する最大ボディサイズ（バイト単位） |
| `message` | `string` | `'Request Entity Too Large'` | リミット超過時のレスポンスボディ |
