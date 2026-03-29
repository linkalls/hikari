# Hikari 🚀

Hikariは、V言語（vlang）で書かれた、**Honoライクで直感的に使える超高速なWebサーバーフレームワーク**です。

## 哲学 (Philosophy)

Hikariの開発は、**「究極のパフォーマンス」と「最高のDeveloper Experience (DX)」を両立させること**を目標にしています。

1. **Honoライクな直感的なAPI**: TypeScriptのHonoに影響を受けた洗練されたAPIを採用しています。コンテキスト（`c.text()`, `c.json()`, `c.param()`）を通じて、簡潔で読みやすいコードを記述できます。
2. **ゼロ・アロケーション (Zero-Allocation Routing)**: ルーティングのホットパス（実行時に最も頻繁に呼び出される部分）において、極限までメモリ割り当てを排除しました。`path.split('/')` は使用せず、V言語の非常に高速な文字列スライス機能（`path[start..end]`）を活用したRadix Tree（Trie木）ルーターを独自に実装しています。これにより、不要なガベージコレクションを抑え、安定した高スループットを実現します。
3. **Picoevによる爆速イベントループ**: バックエンドのI/OイベントループとHTTPパーサーに、世界最速クラスのC言語ライブラリ `picoev` と `picohttpparser` を直接利用することで、V言語ネイティブの強力なパフォーマンスを引き出しています。

## ベンチマーク (Benchmarks)

単一エンドポイントに対するJSONレスポンスのベンチマークにおいて、Hikariは**Go Fiberと同等の速度を記録**し、**Hono (with Bun) の約3.6倍のパフォーマンス**を叩き出しました。

*100コネクション, 100,000リクエスト, `bombardier`を使用（Intel Xeon 2.30GHz, 4 cores, 7.8Gi RAM）*

| Framework | Language | Reqs/sec (Avg) | Latency (Avg) | Throughput |
| :--- | :--- | :--- | :--- | :--- |
| **Hikari** | **VLang** | **84,097 req/s** | **1.18 ms** | 17.35 MB/s |
| Go Fiber | Go | 89,331 req/s | 1.14 ms | 19.14 MB/s |
| Hono | TypeScript (Bun) | 22,862 req/s | 4.38 ms | 5.15 MB/s |

---

## 機能一覧 (Features)

- ✅ **Radix Tree ルーター** — パスパラメータ・ワイルドカード対応
- ✅ **全 HTTP メソッド** — GET, POST, PUT, DELETE, PATCH, HEAD, OPTIONS
- ✅ **HEAD メソッド自動サポート** — GET ルートへのフォールバック
- ✅ **ルートグループ** — `app.group('/api')` でプレフィックスと共通ミドルウェアを適用
- ✅ **全 HTTP ステータスコード** — 200, 201, 204, 301, 302, 400, 401, 403, 429, 503 など
- ✅ **コンテキストストア** — `ctx.set()` / `ctx.get()` でミドルウェア間のデータ共有
- ✅ **リダイレクト** — `ctx.redirect(url, status)`
- ✅ **JSON レスポンス/パース** — `ctx.json()` / `ctx.json_status()` / `ctx.bind_json()`
- ✅ **HTML レスポンス** — `ctx.html()` / `ctx.html_status()`
- ✅ **フォームパース** — multipart/form-data, application/x-www-form-urlencoded
- ✅ **ファイルアップロード** — `ctx.file()` / `ctx.files()`
- ✅ **静的ファイル配信** — ETag, Cache-Control 対応
- ✅ **HttpError 型** — HTTP ステータスコード付きエラー
- ✅ **グローバルエラーハンドリング** — `app.set_error_handler()`
- ✅ **カスタム 404 ハンドラー** — `app.set_not_found_handler()`
- ✅ **標準ミドルウェア** — Logger, CORS, Recover, RateLimit, RequestID, Secure, ETag, BasicAuth, Compress, BodyLimit, **Timeout**
- ✅ **JWT 認証ミドルウェア** — HS256 署名検証・`jwt_sign()` ヘルパー
- ✅ **クッキーサポート** — `ctx.cookie()` / `ctx.cookies()` / `ctx.set_cookie()`
- ✅ **クエリパラメータ** — `ctx.query_value(key)` 便利メソッド
- ✅ **Content-Length 自動付与** — HTTP/1.1 Keep-Alive 効率最適化
- ✅ **ヘッダーキャッシュ** — `ctx.header()` が初回アクセス時にキャッシュを構築し O(1) ルックアップ
- ✅ **ゼロコピー最適化** — ミドルウェアスライスのクローンを必要時のみ実施（ホットパス高速化）
- ✅ **直接ハンドラー呼び出し最適化** — ミドルウェアなしのルートで `MiddlewareChain` ヒープアロケーションを完全回避

---

## 使い方 (Usage)

Hikariを使った簡単なアプリケーションの構築方法です。

### 1. アプリケーションの作成

```v
module main

import hikari

fn main() {
    mut app := hikari.new()

    // シンプルなテキストを返す
    app.get('/', fn (mut c hikari.Context) !hikari.Response {
        return c.text('Welcome to Hikari Web Framework!')
    })

    // パスパラメータを利用する
    app.get('/hello/:name', fn (mut c hikari.Context) !hikari.Response {
        name := c.param('name')
        return c.html('<h1>Hello, ${name}!</h1>')
    })

    // JSONレスポンスを返す
    app.get('/api/data', fn (mut c hikari.Context) !hikari.Response {
        return c.json({
            'framework': 'Hikari'
            'language':  'V'
            'speed':     'Blazing Fast'
        })
    })

    // ポートを指定してサーバーを起動
    app.fire(3000)
}
```

### 2. 実行

V言語のコンパイラを使用して、最適化オプション（`-prod`）を有効にしてコンパイル・実行します。

```bash
v -prod main.v
./main
```

### 3. POSTリクエストとJSONのパース

```v
struct User {
    name string
    age  int
}

app.post('/api/user', fn (mut c hikari.Context) !hikari.Response {
    // リクエストのJSONボディを構造体にマッピング
    user := c.bind_json[User]() or { return error('invalid json') }
    return c.json({
        'message': 'User created'
        'user':    user.name
    })
})
```

### 4. ミドルウェア (Middlewares)

グローバルミドルウェアやルートレベルのミドルウェアを使用できます。

```v
fn logger_mw(mut ctx hikari.Context, next hikari.Next) !hikari.Response {
    println('Request: ${ctx.req.method} ${ctx.req.path}')

    // カスタムヘッダーを追加
    ctx.headers['X-Custom'] = 'Hikari'

    // 次のミドルウェア（またはハンドラ）を実行
    return next(mut ctx)
}

// グローバルミドルウェアとして追加
app.use(logger_mw)

// ルート個別にミドルウェアを追加することも可能
app.get('/admin', fn (mut c hikari.Context) !hikari.Response {
    return c.text('Admin Area')
}, auth_mw)
```

### 5. グローバルなエラーハンドリング (Error Handling)

```v
app.set_error_handler(fn (err IError, mut ctx hikari.Context) !hikari.Response {
    println('Error intercepted: ${err.msg()}')
    ctx.headers['Content-Type'] = 'application/json'
    return ctx.json({ 'error': err.msg() })
})
```

### 6. 静的ファイルの配信 (Static File Serving)

Hikariは、組み込みで静的ファイルの配信機能を提供しています。`app.static(path, root_dir)` メソッドを使用して、指定したディレクトリ内のファイルを簡単に配信できます。

```v
import hikari

mut app := hikari.new()

// '/public' プレフィックスで './public' ディレクトリ内のファイルにアクセスできるようにします
app.static('/public', './public')
```

これによって、たとえば `./public/style.css` というファイルがある場合、クライアントは `/public/style.css` にアクセスしてファイルを取得できます。また、パスにファイル名が指定されていない場合（例: `/public/`）、自動的に `index.html` が検索されます。

### 7. ファイルアップロード (File Uploads)

`multipart/form-data` 形式のリクエストからファイルやフォームデータを簡単に取得できます。

```v
app.post('/upload', fn (mut c hikari.Context) !hikari.Response {
    // フォームデータの取得
    username := c.form_value('username')

    // アップロードされたファイルの取得
    file := c.file('avatar') or { return c.text('No file uploaded') }

    // ファイル情報の利用
    // file.filename (string)
    // file.content_type (string)
    // file.data (string - ファイルの中身)

    return c.text('Uploaded: ${file.filename} by ${username}')
})
```

### 8. 標準ミドルウェア (Standard Middlewares)

Hikariは、組み込みで `Logger`, `CORS`, `Recover` の標準ミドルウェアを提供しています。詳細は [docs/standard_middlewares.md](docs/standard_middlewares.md) を参照してください。

```v
// ロガー
app.use(hikari.logger())

// CORS
app.use(hikari.cors(hikari.CorsOptions{
    allow_origins: ['*']
}))

// リカバリー
app.use(hikari.recover())
```

### 9. ルートグループ (Route Groups)

共通のプレフィックスやミドルウェアを持つルートをグループ化できます。詳細は [docs/route_groups.md](docs/route_groups.md) を参照してください。

```v
// '/api/v1' プレフィックスのグループ
mut api := app.group('/api/v1')

api.get('/users', fn (mut c hikari.Context) !hikari.Response {
    return c.json(['Alice', 'Bob'])
})

api.post('/users', fn (mut c hikari.Context) !hikari.Response {
    return c.send_status(201, 'Created')
})
```

### 10. 新ミドルウェア (New Middlewares)

詳細は [docs/new_middlewares.md](docs/new_middlewares.md) を参照してください。

```v
// レートリミット: 1分間に100リクエストまで
app.use(hikari.rate_limit(hikari.RateLimitOptions{
    max:       100
    window_ms: 60000
}))

// リクエスト ID: 各リクエストに一意のIDを付与
app.use(hikari.request_id())

// セキュリティヘッダー: Helmet風の主要セキュリティヘッダーを自動付与
app.use(hikari.secure(hikari.SecureOptions{}))

// ETag: レスポンスの ETag を自動計算・304 Not Modified を返す
app.use(hikari.etag())

// Gzip 圧縮: Accept-Encoding: gzip を受け付けるクライアントへ圧縮レスポンス
app.use(hikari.compress())

// Basic 認証: ルートやグループに認証を追加
app.use(hikari.basic_auth(hikari.BasicAuthOptions{
    username: 'admin'
    password: 'secret'
}))

// JWT 認証: HS256 トークンを検証し、ペイロードを ctx.store に保存
app.use(hikari.jwt(hikari.JwtOptions{
    secret: 'your-secret-key'
}))
```

### 11. JWT 認証 (JWT Authentication)

HS256 アルゴリズムで JWT トークンを検証します。トークンのペイロード JSON は `ctx.get('jwt_payload')` で取得できます。

```v
import hikari
import json

struct Claims {
    sub  string
    role string
}

// ログイン: JWT トークンを生成して返す
app.post('/login', fn (mut c hikari.Context) !hikari.Response {
    token := hikari.jwt_sign({
        'sub':  'user123'
        'role': 'admin'
    }, 'your-secret-key')
    return c.text(token)
})

// 保護されたルート: JWT ミドルウェアで認証
app.get('/profile', fn (mut c hikari.Context) !hikari.Response {
    payload_str := c.get('jwt_payload')
    // payload_str は JSON 文字列: {"sub":"user123","role":"admin"}
    return c.text('Hello, ${payload_str}')
}, hikari.jwt(hikari.JwtOptions{ secret: 'your-secret-key' }))
```

#### JwtOptions

| フィールド | 型 | デフォルト | 説明 |
|---|---|---|---|
| `secret` | `string` | — | 署名検証に使う秘密鍵（必須） |
| `scheme` | `string` | `'Bearer'` | Authorization ヘッダーのスキーム |
| `unauthorized_message` | `string` | `'Unauthorized'` | 認証失敗時のレスポンスボディ |

### 12. クッキーサポート (Cookie Support)

```v
// ログイン時にセッションクッキーを設定
app.post('/login', fn (mut c hikari.Context) !hikari.Response {
    c.set_cookie('session', 'tok123', hikari.CookieOptions{
        max_age:   3600
        http_only: true
        same_site: 'Strict'
    })
    // 複数のクッキーを設定することも可能
    c.set_cookie('theme', 'dark', hikari.CookieOptions{
        http_only: false
    })
    return c.redirect('/dashboard', 302)
})

// リクエストのクッキーを読み取る
app.get('/me', fn (mut c hikari.Context) !hikari.Response {
    session := c.cookie('session')  // 単一クッキーを取得
    if session == '' {
        return hikari.http_error(401, 'Unauthorized')
    }
    all_cookies := c.cookies()  // 全クッキーを map で取得
    return c.text('Hello! theme=${all_cookies['theme']}')
})
```

### 13. リダイレクトとカスタムステータスコード

```v
// リダイレクト
app.get('/old-path', fn (mut c hikari.Context) !hikari.Response {
    return c.redirect('/new-path', 301)
})

// カスタムステータスコード (201 Created)
app.post('/resource', fn (mut c hikari.Context) !hikari.Response {
    return c.send_status(201, 'Created')
})

// HttpError 型でエラーを返す（ステータスコードを自動適用）
app.get('/protected', fn (mut c hikari.Context) !hikari.Response {
    return hikari.http_error(403, 'Forbidden')
})
```

### 14. コンテキストストアとクエリパラメータ

ミドルウェアとハンドラの間でデータを受け渡すことができます。

```v
fn auth_mw(mut ctx hikari.Context, next hikari.Next) !hikari.Response {
    // ユーザー情報をコンテキストに保存
    ctx.set('user_id', '42')
    ctx.set('user_role', 'admin')
    return next(mut ctx)
}

app.get('/profile', fn (mut ctx hikari.Context) !hikari.Response {
    user_id := ctx.get('user_id')
    return ctx.text('User ID: ${user_id}')
}, auth_mw)

// クエリパラメータの取得（?q=hello&page=2）
app.get('/search', fn (mut c hikari.Context) !hikari.Response {
    q    := c.query_value('q')    // "hello"
    page := c.query_value('page') // "2"
    return c.text('q=${q}, page=${page}')
})
```

### 15. カスタム 404 ハンドラー (Custom Not Found Handler)

デフォルトの 404 レスポンスをカスタマイズできます。

```v
app.set_not_found_handler(fn (mut c hikari.Context) !hikari.Response {
    return c.json_status(404, {
        'error': 'Not Found'
        'path':  c.req.path
    })
})
```

### 16. JSON/HTML カスタムステータスレスポンス

`ctx.json_status()` と `ctx.html_status()` を使用すると、任意のステータスコードで JSON または HTML レスポンスを返せます。

```v
// 201 Created で JSON を返す
app.post('/resource', fn (mut c hikari.Context) !hikari.Response {
    return c.json_status(201, {
        'id':      '42'
        'message': 'Created'
    })
})

// 202 Accepted で HTML を返す
app.post('/async-job', fn (mut c hikari.Context) !hikari.Response {
    return c.html_status(202, '<p>Job accepted. Processing...</p>')
})
```

### 17. タイムアウトミドルウェア (Timeout Middleware)

指定時間内にハンドラが完了しない場合、`408 Request Timeout` を返します。

```v
// 5秒のタイムアウトを設定
app.use(hikari.timeout(hikari.TimeoutOptions{
    timeout_ms: 5000
    message:    'Request Timeout'
}))
```

詳細は [docs/new_middlewares.md](docs/new_middlewares.md) を参照してください。

## 今後の展望

- WebSocketのサポート
- HTTP/2 のサポート