# 速度最適化と新機能 (Performance & New Features)

[English](performance_features_en.md) | [日本語](performance_features.md)

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

`handle_request` 内でも同様に `index_u8('?')` を使用し、`path.contains('?')` + `path.split('?')` という
2段階の操作を1回のオフセット計算に置き換えています。

### Content-Length ヘッダーの自動付与

HTTP/1.1 の keep-alive を正しく機能させるため、全レスポンスに自動的に
`Content-Length` ヘッダーが付与されます。これによりクライアントがボディを
先読みでき、コネクションの再利用効率が向上します。

### ミドルウェアスライスのゼロコピー最適化

`handle_request` のホットパスでは、グローバルミドルウェアとルートミドルウェアを
マージする際に不要なメモリアロケーションを回避します。

| 状況 | 動作 |
|------|------|
| グローバルミドルウェアのみ | クローンせずにスライス参照を使用 |
| ルートミドルウェアのみ | クローンせずにスライス参照を使用 |
| 両方あり | 1 回だけクローンして連結 |

```v
// 不要なクローンを避けるロジック
all_mws := if app.middlewares.len == 0 {
    route_mws                        // クローンなし
} else if route_mws.len == 0 {
    app.middlewares                  // クローンなし
} else {
    mut mws := app.middlewares.clone()
    mws << route_mws                 // 必要な場合のみ 1 回クローン
    mws
}
```

### HTTP メソッド正規化の最適化

標準的な HTTP メソッド（GET, POST, PUT など）は既に大文字で送信されるため、
`to_upper()` によるアロケーションを回避します。

```v
method := match ctx.req.method {
    'GET', 'POST', 'PUT', 'DELETE', 'PATCH', 'HEAD', 'OPTIONS', 'CONNECT', 'TRACE' {
        ctx.req.method  // 既に大文字 → アロケーションなし
    }
    else { ctx.req.method.to_upper() }
}
```

### レスポンスビルダーのヘッダーマップ最適化

`ctx.text()`, `ctx.json()` などのレスポンスビルダーは、`ctx.headers` が空の場合
（ミドルウェアがヘッダーを追加していない場合）に無駄なマップクローンを避けます。

```v
headers: if c.headers.len > 0 { c.headers.clone() } else { map[string]string{} }
```

### ルーターの no-op アペンド除去

`find_route` 内で `middlewares << curr.middlewares` を呼び出す前に
`curr.middlewares.len > 0` を確認し、空スライスの連結を避けます。

---

## 新機能 (New Features)

### JWT 認証ミドルウェア

HS256 アルゴリズムで JWT トークンを検証します。詳細は [new_middlewares.md](new_middlewares.md) を参照してください。

```v
app.use(hikari.jwt(hikari.JwtOptions{
    secret: 'your-secret-key'
}))

// トークン生成
token := hikari.jwt_sign({'sub': 'user1', 'role': 'admin'}, 'your-secret-key')
```

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

---

### 直接ハンドラー呼び出し最適化 (Direct Handler Call Optimization)

`handle_request` のホットパスでは、グローバルミドルウェアもルートミドルウェアも存在しない場合、`MiddlewareChain` 構造体のヒープアロケーションを完全にスキップし、ハンドラを直接呼び出します。

| 状況 | 動作 |
|------|------|
| ミドルウェアあり | `MiddlewareChain` を構築してチェーン実行 |
| ミドルウェアなし | ハンドラを直接呼び出す（ヒープアロケーション 0） |

```v
// ミドルウェアなしのルート → MiddlewareChain アロケーションを完全回避
app.get('/fast', fn (mut c hikari.Context) !hikari.Response {
    return c.text('Blazing Fast!')
})
```

これにより、ミドルウェアを使用しない純粋なルーティングのシナリオ（ベンチマーク計測等）で、リクエストあたりのメモリ割り当てをさらに削減します。

---

## 新機能 (New Features)（続き）

### カスタム 404 ハンドラー

デフォルトの `404 Not Found` レスポンスをカスタマイズできます。

```v
app.set_not_found_handler(fn (mut c hikari.Context) !hikari.Response {
    return c.json_status(404, {'error': 'Not Found', 'path': c.req.path})
})
```

### JSON/HTML カスタムステータスレスポンス

```v
// 201 Created で JSON を返す
return c.json_status(201, {'id': '1', 'name': 'Resource'})

// 202 Accepted で HTML を返す
return c.html_status(202, '<p>Accepted</p>')
```
