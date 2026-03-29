# 新機能ミドルウェア (New Middlewares)

Hikari には以下の標準ミドルウェアが用意されています。

---

## レートリミット (`rate_limit`)

指定されたウィンドウ内のリクエスト数を制限します。DDoS 攻撃対策や API 制限に使用します。

```v
app.use(hikari.rate_limit(hikari.RateLimitOptions{
    max:       100           // 1分間に最大100リクエスト
    window_ms: 60000         // ウィンドウ: 60,000ミリ秒 (1分)
    message:   'Too Many Requests'  // カスタムエラーメッセージ
}))
```

### レスポンスヘッダー

| ヘッダー | 説明 |
|---------|------|
| `X-RateLimit-Limit` | ウィンドウ内の最大リクエスト数 |
| `X-RateLimit-Remaining` | 残りのリクエスト数 |
| `X-RateLimit-Reset` | リセット時刻（Unix タイムスタンプ） |
| `Retry-After` | 次にリトライできるまでの秒数（429 時のみ） |

### カスタムキー関数

```v
app.use(hikari.rate_limit(hikari.RateLimitOptions{
    max: 50
    // IP アドレスなどのカスタムキーでレート制限
    key_fn: fn (mut ctx hikari.Context) string {
        return ctx.header('X-Real-IP')
    }
}))
```

---

## リクエスト ID (`request_id`)

各リクエストに一意の ID を付与します。分散トレーシングやログの紐付けに使用します。

```v
app.use(hikari.request_id())
```

- リクエストに既に `X-Request-ID` ヘッダーが含まれている場合はそれを使用します
- ない場合は UUID v4 を自動生成します
- ハンドラ内から `ctx.get('request_id')` で ID を取得できます

```v
app.get('/api', fn (mut ctx hikari.Context) !hikari.Response {
    id := ctx.get('request_id')
    return ctx.text('Request ID: ${id}')
})
```

---

## セキュリティヘッダー (`secure`)

主要なセキュリティ関連 HTTP ヘッダーを自動付与します（Node.js の Helmet に相当）。

```v
// デフォルト設定で使用
app.use(hikari.secure(hikari.SecureOptions{}))

// カスタム設定
app.use(hikari.secure(hikari.SecureOptions{
    x_content_type_options:  true
    x_frame_options:         'DENY'
    x_xss_protection:        true
    hsts_max_age:            31536000  // 1年
    hsts_include_subdomains: true
    content_security_policy: "default-src 'self'; script-src 'self'"
    referrer_policy:         'strict-origin-when-cross-origin'
}))
```

### 付与されるヘッダー

| ヘッダー | デフォルト値 |
|---------|------------|
| `X-Content-Type-Options` | `nosniff` |
| `X-Frame-Options` | `SAMEORIGIN` |
| `X-XSS-Protection` | `1; mode=block` |
| `Strict-Transport-Security` | `max-age=31536000; includeSubDomains` |
| `Content-Security-Policy` | `default-src 'self'` |
| `Referrer-Policy` | `no-referrer` |
| `X-Download-Options` | `noopen` |
| `X-Permitted-Cross-Domain-Policies` | `none` |

---

## ETag (`etag`)

レスポンスボディの MD5 ハッシュを ETag ヘッダーとして付与します。
クライアントが `If-None-Match` ヘッダーを送信し、ETag が一致する場合は `304 Not Modified` を返して帯域幅を節約します。

```v
app.use(hikari.etag())
```

静的ファイルや変更頻度の低い API レスポンスのキャッシュに有効です。

---

## Basic 認証 (`basic_auth`)

HTTP Basic 認証を実装します。

```v
app.use(hikari.basic_auth(hikari.BasicAuthOptions{
    username: 'admin'
    password: 'secret'
    realm:    '管理エリア'
}))
```

認証に失敗すると `401 Unauthorized` と `WWW-Authenticate` ヘッダーを返します。

---

## Gzip 圧縮 (`compress`)

クライアントが `Accept-Encoding: gzip` を送信している場合に、レスポンスボディを gzip 圧縮します。
帯域幅を削減し、転送速度を向上させます。

```v
app.use(hikari.compress())
```

- 512 バイト未満のレスポンスは圧縮しません（オーバーヘッドが大きいため）
- 既に `Content-Encoding` ヘッダーが付いているレスポンスはスキップします

---

## 使用例: 複数ミドルウェアの組み合わせ

```v
import hikari

fn main() {
    mut app := hikari.new()

    // セキュリティ系ミドルウェアをグローバルに適用
    app.use(hikari.logger())
    app.use(hikari.secure(hikari.SecureOptions{}))
    app.use(hikari.request_id())
    app.use(hikari.compress())

    // API グループにレートリミットを適用
    mut api := app.group('/api')
    api.use(hikari.rate_limit(hikari.RateLimitOptions{
        max:       100
        window_ms: 60000
    }))
    api.use(hikari.etag())

    api.get('/users', fn (mut ctx hikari.Context) !hikari.Response {
        return ctx.json(['Alice', 'Bob'])
    })

    // 管理エリアに Basic 認証を適用
    mut admin := app.group('/admin', hikari.basic_auth(hikari.BasicAuthOptions{
        username: 'admin'
        password: 'securepassword'
    }))

    admin.get('/dashboard', fn (mut ctx hikari.Context) !hikari.Response {
        return ctx.html('<h1>管理ダッシュボード</h1>')
    })

    app.fire(3000)
}
```
